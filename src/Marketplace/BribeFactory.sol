// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {IBribeFactory} from "./interfaces/IBribeFactory.sol";
import {Bribe} from "./Bribe.sol";

contract BribeFactory is IBribeFactory {
    address public last_external_bribe;
    address public immutable ve;

    constructor(address _ve) {
        ve = _ve;
    }

    function createExternalBribe(address[] memory allowedRewards) external returns (address) {
        last_external_bribe = address(new Bribe(msg.sender, ve, allowedRewards));
        return last_external_bribe;
    }
}
