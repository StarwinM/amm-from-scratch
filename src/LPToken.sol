// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";

contract LPToken is MyToken {
    address public amm;

    constructor() {
        amm = msg.sender;
        name = "AMM Liquidity Provider";
        symbol = "LP-MTK";
    }

    modifier onlyAMM() {
        require(msg.sender == amm, "Only AMM can mint/burn");
        _;
    }

    function mint(address to, uint256 amount) public override onlyAMM {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) public onlyAMM {
        totalSupply -= amount;
        balanceOf[from] -= amount;
    }
}