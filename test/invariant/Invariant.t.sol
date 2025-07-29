// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    // these pools have two tokens each
    ERC20Mock poolToken;
    ERC20Mock weth;

    PoolFactory factory;
    TSwapPool pool; // poolToken/WETH
    Handler handler;

    int256 constant STARTING_X = 100e18; // poolToken
    int256 constant STARTING_Y = 50e18; // weth 
    
    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        // create init x & y
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));

        poolToken.approve(address(pool), uint256(STARTING_X));
        weth.approve(address(pool), uint256(STARTING_Y));

        // Deposit into the pool
        pool.deposit(uint256(STARTING_Y), 0, uint256(STARTING_X), uint64(block.timestamp));

        handler = new Handler(pool);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.swapPoolTokenForWethBaseOnOutputWeth.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function statefulFuzz_constantProductFormulaStaysTheSameX() public view returns (bool) {
        // How to assert the δx = (β/(1-β)) * x
        // use handler to report the invariant
        assertEq(handler.expectedDeltaX(), handler.actualDeltaX());
        return true;
    }

    function statefulFuzz_constantProductFormulaStaysTheSameY() public view returns (bool) {
        // How to assert the δx = (β/(1-β)) * x
        // use handler to report the invariant

        // Note that here, the issue in TSwapPool will only be discovered if
        // the final operation in the fuzz test is a swap rather than a deposit.
        // Therefore, the fuzz test is not consistently reproducible unless only
        // swap operations are executed.
        assertEq(handler.expectedDeltaY(), handler.actualDeltaY());
        return true;
    }
}