// SPDX-License-Identifier: MIT

/// @title Blueprint Factory
/// @author Izanagi Dev
/// @notice An abstract contract to help easily create contract factories using the eip-5202 specification for blueprint factory deployments
/// Eip-5202: https://eips.ethereum.org/EIPS/eip-5202

import {BytesLib} from "../libraries/Byteslib.sol";

pragma solidity 0.8.23;

//Todo: Add the ability to create blueprint bytecode off-chain *probably handle this within the factory itself?*

abstract contract BlueprintFactory {
    using BytesLib for bytes;
    using BytesLib for bytes1;

    bytes private constant PREAMBLE = "fe7100";

    function deployBlueprint() internal returns (address) {}

    function createFromBlueprint() internal returns (address) {}

    function blueprintDeployerBytecode(bytes calldata initcode) private returns (bytes memory) {}

    function blueprintPreamble(bytes memory bytecode) private pure returns (uint8, bytes memory, bytes memory) {
        if (!BytesLib.equal(bytecode.slice(0, 2), PREAMBLE)) revert NotBluePrint();
        bytes memory empty;
        uint8 ercVersion = uint8((bytecode[2] & bytes1(0xfc)) >> 2);
        uint8 n_length_bytes = uint8(bytecode[2] & bytes1(0x03));
        if (n_length_bytes == 3) revert ReservedBits();
        uint256 dataLength = uint256(bytes32(bytecode.slice(3, 3 + n_length_bytes)));
        uint256 data_start = 3 + n_length_bytes;
        bytes memory preamble_data = bytes(bytecode.slice(data_start, data_start + dataLength));
        bytes memory initcode = bytecode.slice(3 + n_length_bytes + dataLength, uint256(bytes32(bytecode)));
        if (BytesLib.equal(initcode, empty)) revert NoInitCode();

        return (ercVersion, preamble_data, initcode);
    }

    error NotBluePrint();
    error ReservedBits();
    error NoInitCode();
}
