// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IWithdrawLimitModule {
    function availableWithdrawLimit(address, uint256, address[10] calldata) external view returns (uint256);
}
