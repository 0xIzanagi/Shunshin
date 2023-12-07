// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vault} from "../src/Vaults/Vault.sol";
import {ERC20Mock} from "oz/mocks/token/ERC20Mock.sol";

contract VaultTest is Test {
    ERC20Mock public mock;
    Vault public vault;

    function setUp() public {
        mock = new ERC20Mock();
        vault = new Vault(mock, "MockVault", "MCKV", address(this), 1_000_000);
    }

    function testDeposit() public {}

    function testMint() public {}

    function testRedeem() public {}

    function testWithdraw() public {}

    function testTransfer() public {}

    function testApprove() public {}

    function testIncreaseAllowance() public {}

    function testDecreaseAllowance() public {}

    function testTransferFrom() public {}

    function testAddStrategy() public {}

    function testRevokeStrategy() public {}
}
