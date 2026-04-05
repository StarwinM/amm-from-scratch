// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        token = new MyToken();
    }

    function test_Mint() public {
        token.mint(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.totalSupply(), 1000);
    }

    function test_Transfer() public {
        token.mint(alice, 1000);
        vm.prank(alice); // Next call is from Alice
        token.transfer(bob, 400);
        assertEq(token.balanceOf(bob), 400);
        assertEq(token.balanceOf(alice), 600);
    }

    function test_RevertIf_TransferInsufficientBalance() public {
    token.mint(alice, 100);
    
    vm.prank(alice);
    vm.expectRevert("Insufficient balance"); 
    token.transfer(bob, 200); 
}

    function test_Approve() public {
        token.approve(alice, 500);
        assertEq(token.allowance(address(this), alice), 500);
    }

    // will run this 256 times with random values for 'amount'
    function testFuzz_Transfer(uint256 amount) public {
        vm.assume(amount > 0); // Ignore 0 transfers
        token.mint(alice, amount);
        
        vm.prank(alice);
        token.transfer(bob, amount);
        
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), 0);
    }

    // test ensures the total supply logic NEVER breaks
    function test_InvariantTotalSupply() public {
        token.mint(alice, 1000);
        token.mint(bob, 500);
        assertEq(token.totalSupply(), token.balanceOf(alice) + token.balanceOf(bob));
    }
}