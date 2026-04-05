// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/MyToken.sol";

contract AMMTest is Test {
    AMM amm;
    MyToken tokenA;
    MyToken tokenB;
    address alice = makeAddr("alice");

    function setUp() public {
        tokenA = new MyToken();
        tokenB = new MyToken();
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(alice, 1000 ether);
        tokenB.mint(alice, 1000 ether);

        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 ether);
        tokenB.approve(address(amm), 1000 ether);
        vm.stopPrank();
    }

    function test_InitialLiquidity() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        assertEq(amm.reserveA(), 100 ether);
        assertEq(amm.reserveB(), 100 ether);
        assertTrue(amm.lpToken().balanceOf(alice) > 0);
    }

    function test_SwapSlippageProtection() public {
        vm.startPrank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        
        // Swapping 10 ether should give us ~9 ether
        // If we set minAmountOut to 11, it must revert
        vm.expectRevert("Slippage too high");
        amm.swap(address(tokenA), 10 ether, 11 ether);
        vm.stopPrank();
    }

    function testFuzz_Swap(uint256 amount) public {
        vm.assume(amount > 100 && amount < 500 ether);
        
        vm.startPrank(alice);
        amm.addLiquidity(100 ether, 100 ether);
        uint256 kBefore = amm.reserveA() * amm.reserveB();
        
        amm.swap(address(tokenA), amount, 0);
        
        uint256 kAfter = amm.reserveA() * amm.reserveB();
        // k should increase slightly because of the 0.3% fee
        assertTrue(kAfter >= kBefore, "Invariant k decreased");
        vm.stopPrank();
    }
}