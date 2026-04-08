// SPDX-License-Identifier: MIT.
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking {
    using SafeERC20 for IERC20;

    address public owner;  

    IERC20 public usdt;
    IERC20 public rewardToken;

    uint256 public constant CLAIM_INTERVAL = 1 days;
    uint256 public constant EMERGENCY_FEE = 10; // 10%

    struct Pool {
        uint256 duration;
        uint256 apy;
    }

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaim;
        uint256 poolId;
        address referrer;
        bool active;
    }

    Pool[] public pools;

    mapping(address => StakeInfo[]) public stakes;
    mapping(address => uint256) public referralRewards;
    mapping(address => address) public referrers;

    event Staked(address indexed user, uint256 amount, uint256 poolId);
    event Claimed(address indexed user, uint256 reward);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event ReferralWithdrawn(address indexed user, uint256 amount);

    constructor(address _usdt, address _rewardToken) {
        owner = msg.sender;
        usdt = IERC20(_usdt);
        rewardToken = IERC20(_rewardToken);

        pools.push(Pool(7 days, 5));
        pools.push(Pool(45 days, 7));
        pools.push(Pool(90 days, 9));
        pools.push(Pool(180 days, 11));
        pools.push(Pool(360 days, 13));
        pools.push(Pool(720 days, 20));
    }

    function stake(uint256 poolId, address referrer, uint256 amount) external {
        require(poolId < pools.length, "Invalid pool");
        require(amount > 0, "Invalid amount");

        usdt.safeTransferFrom(msg.sender, address(this), amount);

        if (
            referrers[msg.sender] == address(0) &&
            referrer != address(0) &&
            referrer != msg.sender
        ) {
            referrers[msg.sender] = referrer;
        }

        stakes[msg.sender].push(
            StakeInfo({
                amount: amount,
                startTime: block.timestamp,
                lastClaim: block.timestamp,
                poolId: poolId,
                referrer: referrers[msg.sender],
                active: true
            })
        );

        emit Staked(msg.sender, amount, poolId);
    }

    function calculateReward(address user, uint256 index) public view returns (uint256) {
        require(index < stakes[user].length, "Invalid index");

        StakeInfo storage s = stakes[user][index];
        if (!s.active) return 0;

        Pool memory p = pools[s.poolId];
        uint256 timeDiff = block.timestamp - s.lastClaim;

        return (s.amount * p.apy * timeDiff) / (365 days * 100);
    }

    function claim(uint256 index) external {
        require(index < stakes[msg.sender].length, "Invalid index");

        StakeInfo storage s = stakes[msg.sender][index];
        require(s.active, "Inactive");
        require(block.timestamp >= s.lastClaim + CLAIM_INTERVAL, "Wait 24h");

        uint256 reward = calculateReward(msg.sender, index);
        require(reward > 0, "No reward");
        require(rewardToken.balanceOf(address(this)) >= reward, "Insufficient rewards");

        s.lastClaim = block.timestamp;

        address upline = s.referrer;
        for (uint256 i = 0; i < 5; i++) {
            if (upline == address(0)) break;

            uint256 bonus = reward / 100;
            referralRewards[upline] += bonus;

            upline = referrers[upline];
        }

        rewardToken.safeTransfer(msg.sender, reward);

        emit Claimed(msg.sender, reward);
    }

    function withdrawReferral() external {
        uint256 amount = referralRewards[msg.sender];
        require(amount > 0, "No rewards");

        referralRewards[msg.sender] = 0;
        rewardToken.safeTransfer(msg.sender, amount);

        emit ReferralWithdrawn(msg.sender, amount);
    }

    function unstake(uint256 index) external {
        require(index < stakes[msg.sender].length, "Invalid index");

        StakeInfo storage s = stakes[msg.sender][index];
        require(s.active, "Inactive");

        Pool memory p = pools[s.poolId];
        require(block.timestamp >= s.startTime + p.duration, "Locked");

        uint256 reward = calculateReward(msg.sender, index);
        require(rewardToken.balanceOf(address(this)) >= reward, "Insufficient rewards");

        s.active = false;

        usdt.safeTransfer(msg.sender, s.amount);
        rewardToken.safeTransfer(msg.sender, reward);

        emit Unstaked(msg.sender, s.amount, reward);
    }

    function emergencyUnstake(uint256 index) external {
        require(index < stakes[msg.sender].length, "Invalid index");

        StakeInfo storage s = stakes[msg.sender][index];
        require(s.active, "Inactive");

        uint256 fee = (s.amount * EMERGENCY_FEE) / 100;
        uint256 payout = s.amount - fee;

        s.active = false;

        usdt.safeTransfer(msg.sender, payout);

        emit EmergencyWithdraw(msg.sender, payout);
    }
}
