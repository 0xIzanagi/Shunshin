// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

interface IFactory {
    function protocol_fee_config() external view returns (uint16, address);
}
