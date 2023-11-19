// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

///@title Maru
///@author Koto Protocol
///@notice

import {FraxlendPair} from "./Fraxlend/FraxlendPair.sol";
import {IMaker} from "./interfaces/IMaker.sol";
import {BaseStrategy} from "../../Vaults/BaseStrategy.sol";

contract Maru is BaseStrategy, FraxlendPair {
    constructor(
        address _asset,
        string memory _name,
        bytes memory _configData,
        bytes memory _immutables,
        bytes memory _customConfigData
    ) BaseStrategy(_asset, _name) FraxlendPair(_configData, _immutables, _customConfigData) {}

    function _deployFunds(uint256 _amount) internal virtual override {}

    function _freeFunds(uint256 _amount) internal virtual override {}

    function _harvestAndReport() internal virtual override returns (uint256 _totalAssets) {}
}
