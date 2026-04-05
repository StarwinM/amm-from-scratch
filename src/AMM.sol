// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";
import "./LPToken.sol";

contract AMM {
    MyToken public tokenA;
    MyToken public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = MyToken(_tokenA);
        tokenB = MyToken(_tokenB);
        lpToken = new LPToken();
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lpToMint) {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        if (lpToken.totalSupply() == 0) {
            lpToMint = sqrt(amountA * amountB);
        } else {
            lpToMint = min((amountA * lpToken.totalSupply()) / reserveA, (amountB * lpToken.totalSupply()) / reserveB);
        }

        require(lpToMint > 0, "Insufficient LP minted");
        reserveA += amountA;
        reserveB += amountB;
        
        lpToken.mint(msg.sender, lpToMint);
        emit LiquidityAdded(msg.sender, amountA, amountB, lpToMint);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        bool isTokenA = tokenIn == address(tokenA);
        (MyToken tIn, MyToken tOut, uint256 rIn, uint256 rOut) = isTokenA 
            ? (tokenA, tokenB, reserveA, reserveB) 
            : (tokenB, tokenA, reserveB, reserveA);

        tIn.transferFrom(msg.sender, address(this), amountIn);
        uint256 amountOut = getAmountOut(amountIn, rIn, rOut);
        
        // Requirement: Slippage protection
        require(amountOut >= minAmountOut, "Slippage too high");

        tOut.transfer(msg.sender, amountOut);

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    // Helper functions
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) { z = x; x = (y / x + x) / 2; }
        } else if (y != 0) { z = 1; }
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
}