// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StakingTest is Test {
    Staking staking;
    MockERC20 usdt;
    MockERC20 reward;

    address user = address(1);

    function setUp() public {
        usdt = new MockERC20("USDT", "USDT");
        reward = new MockERC20("Reward", "RWD");

        staking = new Staking(address(usdt), address(reward));

        usdt.mint(user, 1000 ether);
        reward.mint(address(staking), 1000 ether);

        vm.startPrank(user);
        usdt.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }

    function testStake() public {
        vm.startPrank(user);

        staking.stake(0, address(0), 100 ether);

        vm.stopPrank();

        (uint256 amount,,,,,) = staking.stakes(user, 0);

        assertEq(amount, 100 ether);
    }

    function testClaimReward() public {
        vm.startPrank(user);

        staking.stake(0, address(0), 100 ether);

        vm.warp(block.timestamp + 1 days);

        staking.claim(0);

        vm.stopPrank();

        uint256 balance = reward.balanceOf(user);
        assertGt(balance, 0);
    }

    function testUnstake() public {
        vm.startPrank(user);

        staking.stake(0, address(0), 100 ether);

        vm.warp(block.timestamp + 8 days);

        staking.unstake(0);

        vm.stopPrank();

        uint256 balance = usdt.balanceOf(user);
        assertEq(balance, 1000 ether);
    }

    function testEmergencyUnstake() public {
        vm.startPrank(user);

        staking.stake(0, address(0), 100 ether);

        staking.emergencyUnstake(0);

        vm.stopPrank();

        uint256 balance = usdt.balanceOf(user);
        assertEq(balance, 990 ether);
    }
}
