// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/MyToken.sol";

contract LendingPoolTest is Test {
    LendingPool pool;
    MyToken collateral;
    MyToken borrowAsset;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        collateral = new MyToken();
        borrowAsset = new MyToken();
        pool = new LendingPool(address(collateral), address(borrowAsset));

        borrowAsset.mint(address(pool), 10_000 ether);

        collateral.mint(alice, 1000 ether);
        borrowAsset.mint(alice, 1000 ether);

        collateral.mint(bob, 1000 ether);
        borrowAsset.mint(bob, 1000 ether);

        borrowAsset.mint(liquidator, 10_000 ether);


        vm.startPrank(alice);
        collateral.approve(address(pool), type(uint256).max);
        borrowAsset.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        collateral.approve(address(pool), type(uint256).max);
        borrowAsset.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidator);
        borrowAsset.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }


    function test_Deposit() public {
        vm.prank(alice);
        pool.deposit(100 ether);

        (uint256 deposited, uint256 borrowed) = pool.getPosition(alice);
        assertEq(deposited, 100 ether);
        assertEq(borrowed, 0);
    }

    function test_WithdrawFull() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.withdraw(100 ether);
        vm.stopPrank();

        (uint256 deposited,) = pool.getPosition(alice);
        assertEq(deposited, 0);
        assertEq(collateral.balanceOf(alice), 1000 ether);
    }

    function test_WithdrawPartial() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.withdraw(40 ether);
        vm.stopPrank();

        (uint256 deposited,) = pool.getPosition(alice);
        assertEq(deposited, 60 ether);
    }


    function test_BorrowWithinLTV() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(75 ether); 
        vm.stopPrank();

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, 75 ether);
    }

    function test_RevertIf_BorrowExceedsLTV() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);

        vm.expectRevert("Exceeds LTV limit");
        pool.borrow(76 ether); 
        vm.stopPrank();
    }

    function test_RevertIf_BorrowWithZeroCollateral() public {
        vm.prank(alice);
        vm.expectRevert("No collateral deposited");
        pool.borrow(10 ether);
    }


    function test_RepayFull() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(50 ether);
        vm.stopPrank();

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, 0);
    }

    function test_RepayPartial() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(20 ether);
        vm.stopPrank();

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, 30 ether);
    }


    function test_RevertIf_WithdrawDropsHealthFactor() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(70 ether);

        vm.expectRevert("Health factor would drop below 1");
        pool.withdraw(20 ether); 
        vm.stopPrank();
    }


    function test_LiquidateAfterPriceDrop() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(70 ether);
        vm.stopPrank();

        pool.setCollateralPrice(0.5e18);


        uint256 hf = pool.getHealthFactor(alice);
        assertTrue(hf < 1e18, "Should be undercollateralized");

  
        vm.prank(liquidator);
        pool.liquidate(alice);

        (, uint256 borrowed) = pool.getPosition(alice);
        assertEq(borrowed, 0);
    }

    function test_RevertIf_LiquidateHealthyPosition() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        vm.prank(liquidator);
        vm.expectRevert("Position is healthy");
        pool.liquidate(alice);
    }



    function test_InterestAccruesOverTime() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        // Warp 1 year (365 days)
        vm.warp(block.timestamp + 365 days);

        (, uint256 borrowed) = pool.getPosition(alice);
        // Should be more than 50 ether due to interest (~1% per year)
        assertTrue(borrowed > 50 ether, "Interest should accrue");
        // Should be roughly 50.5 ether (50 * 1.01)
        assertTrue(borrowed < 51 ether, "Interest should be reasonable");
    }
}
