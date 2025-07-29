// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Registry} from "../../src/Registry.sol";

contract RegistryTest is Test {
    Registry registry;
    address alice;

    function setUp() public {
        alice = makeAddr("alice");
        
        registry = new Registry();
    }

    function test_register() public {
        uint256 amountToPay = registry.PRICE();
        
        vm.deal(alice, amountToPay);
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = address(alice).balance;

        registry.register{value: amountToPay}();

        uint256 aliceBalanceAfter = address(alice).balance;
        
        assertTrue(registry.isRegistered(alice), "Did not register user");
        assertEq(address(registry).balance, registry.PRICE(), "Unexpected registry balance");
        assertEq(aliceBalanceAfter, aliceBalanceBefore - registry.PRICE(), "Unexpected user balance");
    }

    /** Code your fuzz test here */
    function test_register_fuzz(uint256 amount) public {
        uint256 amountToPay = registry.PRICE();
        amount = bound(amount, amountToPay, type(uint256).max);
        
        vm.deal(alice, amount);
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = address(alice).balance;

        registry.register{value: amount}();

        uint256 aliceBalanceAfter = address(alice).balance;
        
        assertTrue(registry.isRegistered(alice), "Did not register user");
        assertEq(address(registry).balance, registry.PRICE(), "Unexpected registry balance");
        assertEq(aliceBalanceAfter, aliceBalanceBefore - registry.PRICE(), "Unexpected user balance");
    }
}