// SPDX-License-Identifier: GNU AGPLv3

///@title Vault Factory
///@author Izanagi Dev
///@notice Deploy Vaults of the same API version
/// solidity version of Yearn V3 Vault Factory
/// https://github.com/yearn/yearn-vaults-v3/blob/master/contracts/VaultFactory.vy

pragma solidity 0.8.23;

import {Vault} from "./Vault.sol";
import {ERC20} from "oz/token/ERC20/ERC20.sol";

contract VaultFactory {
    struct ProtocolFeeConfig {
        // Percent of protocol's split of fees in Basis Points.
        uint16 feeBps;
        //  Address the protocol fees get paid to.
        address receipient;
    }

    string public constant API_VERSION = "3.0.1";
    // The max amount the protocol fee can be set to.
    uint16 public constant MAX_FEE_BPS = 5_000; // 50%
    // The address that all newly deployed vaults are based from.
    address public immutable vaultBlueprint;
    // State of the Factory. If True no new vaults can be deployed.
    bool public shutdown;
    // Address that can set or change the fee configs.
    address public governance;
    // Pending governance waiting to be accepted.
    address public pendingGovernance;
    // Name for identification.
    string public name;
    // The default config for assessing protocol fees.
    ProtocolFeeConfig public config;
    // Custom fee to charge for a specific vault or strategy.
    mapping(address => uint16) public customFeeConfig;
    // Represents if a custom protocol fee should be used.
    mapping(address => bool) public useCustomConfig;
    // Represents if a address is a vault deployed from the factory or not
    mapping(address => bool) public isVault;

    constructor(string memory _name, address _vaultBlueprint, address _governance) {
        name = _name;
        vaultBlueprint = _vaultBlueprint;
        governance = _governance;
    }

    function deploy(ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _roleManager,
        uint256 _profitMaxUnlockTime) external returns (address vault) {
            vault = address(new Vault(_asset, _name, _symbol, _roleManager, _profitMaxUnlockTime));
        }

    function apiVersion() external pure returns (string memory) {
        return API_VERSION;
    }

    function protocolFeeConfig() external view returns (ProtocolFeeConfig memory) {
        if (useCustomConfig[msg.sender]) {
            return ProtocolFeeConfig(customFeeConfig[msg.sender], config.receipient);
        } else {
            return config;
        }
    }

    function setProtocolFeeBps(uint16 newProtocolFeeBps) external {
        if (msg.sender != governance) revert OnlyGov();

        config.feeBps = newProtocolFeeBps;
    }

    function setProtocolFeeReceipient(address receipient) external {
        if (msg.sender != governance) revert OnlyGov();
        if (receipient == address(0)) revert ZeroAddress();
        config.receipient = receipient;
    }

    function setCustomProtocolFeeBps(address vault, uint16 customProtocolFee) external {
        if (msg.sender != governance) revert OnlyGov();
        if (customProtocolFee > MAX_FEE_BPS) revert MaxFeeBps();
        if (config.receipient == address(0)) revert ZeroAddress();

        customFeeConfig[vault] = customProtocolFee;
        if (!useCustomConfig[vault]) {
            useCustomConfig[vault] = true;
        }
    }

    function removeCustomProtocolFee(address vault) external {
        if (msg.sender != governance) revert OnlyGov();
        customFeeConfig[vault] = 0;
        useCustomConfig[vault] = false;
    }

    function shutdownFactory() external {
        if (msg.sender != governance) revert OnlyGov();
        if (shutdown) revert FactoryShutdown();
        shutdown = true;
    }

    function setGovernance(address newGovernance) external {
        if (msg.sender != governance) revert OnlyGov();
        pendingGovernance = newGovernance;
    }

    function acceptGovernance() external {
        if (msg.sender != pendingGovernance) revert NotPendingGov();
        governance = msg.sender;
        pendingGovernance = address(0);
    }

    event NewVault(address indexed vaultAddress, address indexed asset);
    event UpdateProtocolFeeBps(uint16 oldFeeBps, uint16 newFeeBps);
    event UpdateProtocolFeeRecipient(address indexed oldFeeReceipient, address indexed newFeeReceipient);
    event UpdateCustomProtocolFee(address indexed vault, uint16 newCustomProtocolFee);
    event RemovedCustomProtocolFee(address indexed vault);
    event FactoryClose(uint256 timestamp);
    event UpdateGovernance(address indexed governance);
    event NewPendingGovernance(address indexed pendingGovernance);

    error FactoryShutdown();
    error OnlyGov();
    error MaxFeeBps();
    error ZeroAddress();
    error NotPendingGov();
}
