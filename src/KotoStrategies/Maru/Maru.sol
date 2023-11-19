// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

///@title Maru
///@author Koto Protocol
///@notice

import {IFraxlendPair} from "./Fraxlend/interfaces/IFraxlendPair.sol";
import {IMaker} from "./interfaces/IMaker.sol";
import {BaseStrategy} from "../../Vaults/BaseStrategy.sol";

contract Maru is BaseStrategy {
    IFraxlendPair public immutable pair;

    constructor(address _asset, string memory _name, address _pair) BaseStrategy(_asset, _name) {
        pair = IFraxlendPair(_pair);
    }

    function _deployFunds(uint256 _amount) internal virtual override {}

    function _freeFunds(uint256 _amount) internal virtual override {}

    function _harvestAndReport() internal virtual override returns (uint256 _totalAssets) {}
}
