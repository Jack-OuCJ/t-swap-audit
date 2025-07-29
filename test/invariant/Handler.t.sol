// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";

contract Handler is Test {
    TSwapPool pool; // poolToken/WETH
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    // ghost variable
    int256 startingX;
    int256 startingY;
    int256 public expectedDeltaY;
    int256 public expectedDeltaX;
    int256 public actualDeltaY;
    int256 public actualDeltaX;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(_pool.getWeth());
        poolToken = ERC20Mock(_pool.getPoolToken());
    }

    function swapPoolTokenForWethBaseOnOutputWeth(uint256 outputWeth) public {
        if (weth.balanceOf(address(pool)) <= pool.getMinimumWethDepositAmount()) {
            return;
        }
        outputWeth = bound(outputWeth, pool.getMinimumWethDepositAmount(), weth.balanceOf(address(pool)));
        if (outputWeth == weth.balanceOf(address(pool))) {
            return;
        }
        uint256 poolTokenInputAmount = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        if (poolTokenInputAmount > type(uint64).max) {
            return;
        }

        startingX = int256(poolToken.balanceOf(address(pool))); // startingX = poolToken.balanceOf(address(this));
        startingY = int256(weth.balanceOf(address(pool))); // startingY = weth.balanceOf(address(this));
        expectedDeltaX = int256(poolTokenInputAmount); // expectedDeltaX = poolTokenInputAmount;
        expectedDeltaY = int256(outputWeth) * -1; // expectedDeltaY = outputWeth;

        if (poolToken.balanceOf(swapper) < poolTokenInputAmount) {
            poolToken.mint(swapper, poolTokenInputAmount - poolToken.balanceOf(swapper) + 1);
        }
        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint64).max);
        pool.swapExactOutput(
            poolToken, 
            weth, 
            outputWeth, 
            uint64(block.timestamp)
        );
        vm.stopPrank();

        uint256 endingX = poolToken.balanceOf(address(pool));
        uint256 endingY = weth.balanceOf(address(pool));
        

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }
    
    // deposit, swapExactOutput
    function deposit(uint256 wethAmount) public {
        // make sure it's a reasonable amount
        wethAmount = bound(wethAmount, pool.getMinimumWethDepositAmount(), type(uint64).max);
        startingX = int256(poolToken.balanceOf(address(pool))); // startingX = poolToken.balanceOf(address(this));
        startingY = int256(weth.balanceOf(address(pool))); // startingY = weth.balanceOf(address(this));

        uint256 inputAmount = pool.getPoolTokensToDepositBasedOnWeth(wethAmount);
        expectedDeltaY = int256(wethAmount); // expectedDeltaY = wethAmount;
        expectedDeltaX = int256(inputAmount); // expectedDeltaX = pool.getPoolTokensToDepositBasedOnWeth(wethAmount);

        // deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, inputAmount);

        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(uint256(expectedDeltaY), 0, uint256(expectedDeltaX), uint64(block.timestamp));
        vm.stopPrank();

        // actual
        uint256 endingY = weth.balanceOf(address(pool));
        uint256 endingX = poolToken.balanceOf(address(pool));

        actualDeltaY = int256(endingY) - int256(startingY); // actualDeltaY = endingY - startingY;
        actualDeltaX = int256(endingX) - int256(startingX);
    }
}