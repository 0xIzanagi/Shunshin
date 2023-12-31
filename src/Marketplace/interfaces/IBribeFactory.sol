// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IBribeFactory {
    function createExternalBribe(address[] memory) external returns (address);
}
