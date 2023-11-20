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

    /// @notice deposit into the fraxlend pool in order to start receiving yield. Users receive an equavilant amount of tokens
    /// as if they were depositing into the pool directly. These tokens are the ones that will be used to stake within gauges
    /// in order to receive additional rewards.
    function _deployFunds(uint256 _amount) internal virtual override {
        pair.deposit(_amount, address(this));
    }

    /// @notice withdraw funds from the fraxlend pair to return back to the user.
    function _freeFunds(uint256 _amount) internal virtual override {
        pair.redeem(_amount, address(this), address(this));
    }

    function _harvestAndReport() internal virtual override returns (uint256 _totalAssets) {}
}
