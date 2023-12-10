// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import {IStrategy} from "../../src/Vaults/interfaces/IStrategy.sol";

contract MockStrategy is IStrategy {
    constructor() {}

    function asset() external view returns (address) {}
    function balanceOf(address) external view returns (uint256) {}
    function maxDeposit(address) external view returns (uint256) {}
    function redeem(uint256, address, address) external returns (uint256) {}
    function deposit(uint256, address) external returns (uint256) {}
    function totalAssets() external view returns (uint256) {}
    function convertToAssets(uint256) external view returns (uint256) {}
    function convertToShares(uint256) external view returns (uint256) {}
    function previewWithdraw(uint256) external view returns (uint256) {}
    function maxRedeem(address) external view returns (uint256) {}
}
