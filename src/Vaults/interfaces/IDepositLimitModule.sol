// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IDepositLimitModule {
    function availableDepositLimit(address) external view returns (uint256);
}
