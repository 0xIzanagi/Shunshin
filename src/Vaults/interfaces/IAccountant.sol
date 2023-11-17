// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IAccountant {
    function report(address, uint256, uint256) external returns (uint256, uint256);
}
