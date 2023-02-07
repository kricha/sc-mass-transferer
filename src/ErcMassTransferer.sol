// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

interface IERC20EXT is IERC20, IERC20Metadata {}

contract MassTransferer is Ownable, Pausable {
    event MassTransferComplete(address indexed token, uint256 total);

    using SafeERC20 for IERC20EXT;

    mapping(address => uint8) internal noFeeSenders;
    uint256 internal fee = 0.002 ether;
    uint8 internal maxTransfersNumber = 200;
    bool internal stopped = false;
    string internal newContract = "0x0";

    constructor() {
        _pause();
    }

    modifier whenNotStopped() {
        require(!stopped, string.concat("Contract is stopped, new at: ", newContract));
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function setStopped(bool _state) external onlyOwner {
        stopped = _state;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setMaxTransfersNumber(uint8 _count) external onlyOwner {
        maxTransfersNumber = _count;
    }

    function getFee() external view returns (uint256) {
        return noFeeSenders[msg.sender] == 1 ? 0 : fee;
    }

    function setNewContract(string calldata _addr) external onlyOwner {
        newContract = _addr;
    }

    function addNoFeeAddress(address _address) external onlyOwner {
        noFeeSenders[_address] = 1;
    }

    function delNoFeeAddress(address _address) external onlyOwner {
        delete noFeeSenders[_address];
    }

    // sending tokens with simple recipients and amounts arrays
    function sendToken(address _token, address[] memory _recipients, uint256[] memory _amounts)
        public
        payable
        whenNotPaused
        whenNotStopped
    {
        _makeTransfer(_token, _recipients, _amounts);
    }

    function sendMain(address[] memory _recipients, uint256[] memory _amounts)
        external
        payable
        whenNotStopped
        whenNotPaused
    {
        _makeTransfer(address(0x0), _recipients, _amounts);
    }

    function _makeTransfer(address _token, address[] memory _recipients, uint256[] memory _amounts) private {
        // check if lenght of recipients and amounts is same
        require(_recipients.length == _amounts.length, "invalid recipient and amount arrays");
        // check if transfers count is less or eq than limit
        require(_recipients.length <= maxTransfersNumber, "max transfers number exceeded");
        uint256 _total = 0;
        // calculate fee for request
        uint256 _totalFee = noFeeSenders[msg.sender] == 0 ? _recipients.length * fee : 0;
        require(msg.value >= _totalFee, "no fee provided");

        for (uint256 i = 0; i < _amounts.length; i++) {
            _total += _amounts[i];
        }

        if (_token == address(0x0)) {
            require(msg.value >= _total + _totalFee, "not enough value");
            for (uint256 i = 0; i < _recipients.length; i++) {
                (bool success,) = _recipients[i].call{value: _amounts[i]}("");
                require(success, "Transfer failed.");
            }
        } else {
            IERC20EXT token = IERC20EXT(_token);

            uint256 _balance = token.balanceOf(msg.sender);
            require(_balance >= _total, "not enough token balance");

            uint256 _allowance = token.allowance(msg.sender, address(this));
            require(_allowance >= _total, "not enough token allowance");

            for (uint256 i = 0; i < _recipients.length; i++) {
                token.safeTransferFrom(msg.sender, _recipients[i], _amounts[i]);
            }
        }

        emit MassTransferComplete(_token, _total);
    }

    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "zero balance");
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function withdrawToken(IERC20EXT _token) external onlyOwner {
        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "zero balance");
        _token.safeTransfer(owner(), amount);
    }

    receive() external payable {}
    fallback() external payable {}
}
