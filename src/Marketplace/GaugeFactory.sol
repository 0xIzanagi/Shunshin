// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Gauge} from "./Gauge.sol";
import {IGaugeFactory} from "./interfaces/IGaugeFactory.sol";

contract GaugeFactory is IGaugeFactory {
    address public last_gauge;

    function createGauge(address _stakingToken, address _rewardToken) external returns (address) {
        last_gauge = address(new Gauge(_stakingToken, _rewardToken, msg.sender));
        return last_gauge;
    }
}
