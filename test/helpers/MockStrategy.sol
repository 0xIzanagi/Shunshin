// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import {IStrategy} from "../../src/Vaults/interfaces/IStrategy.sol";
import {ERC20} from "oz/token/ERC20/ERC20.sol";

contract MockStrategy is IStrategy {
    ERC20 private immutable _asset;
    uint256 private _maxDeposit;

    constructor(address _asset_) {
        _asset = ERC20(_asset_);
    }

    function asset() external view override returns (address) {
        return address(_asset);
    }

    function balanceOf(address) external view returns (uint256) {}
    function maxDeposit(address) external view returns (uint256) {
        return _maxDeposit;
    }
    function redeem(uint256, address, address) external returns (uint256) {}
    function deposit(uint256 value, address receiver) external returns (uint256) {
        _asset.transferFrom(msg.sender, address(this), value);
    }
    function totalAssets() external view returns (uint256) {}
    function convertToAssets(uint256) external view returns (uint256) {}
    function convertToShares(uint256) external view returns (uint256) {}
    function previewWithdraw(uint256) external view returns (uint256) {}
    function maxRedeem(address) external view returns (uint256) {}

    function setMaxDeposit(uint256 amount) external {
        _maxDeposit = amount;
    }
}
