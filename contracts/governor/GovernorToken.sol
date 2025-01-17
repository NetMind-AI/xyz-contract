// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract GovernorToken is Initializable, OwnableUpgradeable,ReentrancyGuardUpgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable {
    using SafeERC20 for IERC20;
    IERC20 public token;
    uint256 public matureAt;

    /// @custom:oz-upgrades-unsafe-allow constructor
     constructor() {
         _disableInitializers();
     }

    function initialize(
        address tokenAddr,
        string memory name,
        string memory symbol,
        uint256 endTime
    ) initializer public {
        token = IERC20(tokenAddr);
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __ERC20Permit_init(name);
        __ERC20Votes_init();
        __ReentrancyGuard_init();
        __Ownable_init(_msgSender());
        matureAt = endTime;
    }

    function setMatureAt(uint256 matureAt_) public onlyOwner {
        require(matureAt_ > block.timestamp, "matureAt_ err");
        matureAt = matureAt_;
    }

    function stake(uint256 amount, address delegatee) public nonReentrant(){
        require(delegatee != address(0), "delegatee err");
        address sender = _msgSender();
        token.safeTransferFrom(sender, address(this), amount);
        _delegate(sender, delegatee);
        _mint(sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant(){
        _burn(_msgSender(), amount);
        token.safeTransfer(_msgSender(), amount);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
    internal
    override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        if(from == owner()){
            require(block.timestamp > matureAt, "Not mature yet");
        }
        super._update(from, to, value);
    }

    function nonces(address owner)
    public
    view
    override(ERC20PermitUpgradeable, NoncesUpgradeable)
    returns (uint256)
    {
        return super.nonces(owner);
    }
}
