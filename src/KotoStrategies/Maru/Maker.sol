// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title Maker
/// @author Koto Protocol
/// @notice The maker contract is used in conjunction alongside the lending pool to allow users to interact with xTokens from the f(x) protocol.
/// this contract handles all minting and redeeming of xTokens as well as converting ETH to stETH if necessary. Liquidations of loans from the associated lending
/// pool are handled inside of the lending contract, but if need be use xTokens held within this contract to held payback the debt.

import {IMaker} from "./interfaces/IMaker.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import {IMaru} from "./interfaces/IMaru.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";

contract Maker is IMaker {
    IMarket public immutable market;
    IMaru public immutable maru;

    mapping(address => uint256) public balanceOf;

    modifier onlyMaru(address caller) {
        if (caller != address(maru)) revert OnlyMaru();
        _;
    }

    constructor(address _market, address _maru) {
        market = IMarket(_market);
        maru = IMaru(_maru);
    }

    /// @inheritdoc IMaker
    function mint(address _sender, address _tokenIn, uint256 _amount)
        external
        onlyMaru(msg.sender)
        returns (uint256 xTokenOut, uint256 extraBaseTokenOut)
    {
        uint256 baseTokenOut = _amount;
        if (_tokenIn != market.baseToken()) {
            baseTokenOut = _swap(_amount);
        }
        uint256 preBalance = IERC20(market.xToken()).balanceOf(address(this));
        (xTokenOut, extraBaseTokenOut) = market.mintXToken(baseTokenOut, address(this), 0);
        uint256 postBalance = IERC20(market.xToken()).balanceOf(address(this));
        xTokenOut = xTokenOut == (postBalance - preBalance) ? xTokenOut : (postBalance - preBalance);
        balanceOf[_sender] = xTokenOut;
        if (extraBaseTokenOut > 0) {
            IERC20(market.baseToken()).transfer(_sender, extraBaseTokenOut);
        }

        emit MintXToken(_sender, _tokenIn, _amount, balanceOf[_sender], extraBaseTokenOut);
        return (xTokenOut, extraBaseTokenOut);
    }
    /// @inheritdoc IMaker
    function redeem(address _sender, uint256 _amount) external onlyMaru(msg.sender) {
        if (balanceOf[_sender] < _amount) revert InsufficentBalance();
        balanceOf[_sender] -= _amount;
        uint256 amountOut = market.redeem(0, _amount, address(this), 0);
        uint256 repayment = _swap(amountOut);
    }

    function _mint() private {}

    function _swap(uint256 amount) internal returns (uint256) {}

    function liquidate(address _user, uint256 _amount) external onlyMaru(msg.sender) {}

    error OnlyMaru();
    error InsufficentBalance();

    event MintXToken(
        address indexed user, address tokenIn, uint256 amountIn, uint256 userBalance, uint256 extraBaseToken
    );
}
