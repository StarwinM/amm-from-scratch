// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// --- INTERFACES ---
// Required to interact with existing Mainnet contracts
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

contract ForkTest is Test {
    // Constants for Mainnet Addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        // Requirement: Fork Ethereum mainnet
        vm.createSelectFork(MAINNET_RPC_URL);
    }

    function test_ReadUSDCTotalSupply() public view {
        uint256 totalSupply = IERC20(USDC).totalSupply();
        
        
        console.log("Real USDC Total Supply:", totalSupply);
        
        assertTrue(totalSupply > 0, "Failed to read USDC supply");
    }

    function test_SimulateUniswapSwap() public {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        uint256 amountIn = 1 ether;
        uint256 deadline = block.timestamp + 15;

        // Give this test contract 1 ETH to perform the swap
        vm.deal(address(this), amountIn);
        
        // Perform the swap
        router.swapExactETHForTokens{value: amountIn}(
            0, // amountOutMin: 0 for simple simulation
            path,
            address(this),
            deadline
        );

        uint256 daiBalance = IERC20(DAI).balanceOf(address(this));
        
       
        console.log("ETH Swapped: 1.0");
        console.log("DAI Received:", daiBalance / 1e18); 
        
        assertTrue(daiBalance > 0, "Swap resulted in 0 tokens");
    }

    receive() external payable {}
}