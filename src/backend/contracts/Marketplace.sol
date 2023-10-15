// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract Marketplace is ReentrancyGuard {
    // Variables
    address payable public immutable feeAccount; // the account that receives fees
    uint public immutable feePercent; // the fee percentage on sales
    uint public itemCount;

    struct Item {
        uint itemId;
        IERC721 nft;
        uint tokenId;
        uint price;
        address payable seller;
        bool sold;
    }

    // itemId -> Item
    mapping(uint => Item) public items;

    // How musch item are listed in this contract
    mapping(address => mapping(uint => Item)) private Listed_Items;

    //seller address -> Amount earned
    mapping(address => uint) private AmountEarned;

    event Offered(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );
    event Bought(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );
    event Cancel(uint itemId, address indexed nft);

    constructor(uint _feePercent) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    modifier onlyOwner(address seller) {
        require(msg.sender == seller, "only Owner will have access");
        _;
    }

    // list item to offer on the marketplace
    function listItem(
        IERC721 _nft,
        uint _tokenId,
        uint _price
    ) external nonReentrant onlyOwner(msg.sender) {
        require(_price > 0, "Price must be greater than zero");

        // add new item to items mapping
        items[itemCount] = Item(
            itemCount,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            false
        );
        // increment itemCount
        itemCount++;
        // transfer nft
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        // emit Offered event
        emit Offered(itemCount, address(_nft), _tokenId, _price, msg.sender);
    }

    function purchaseItem(uint _itemId) external payable nonReentrant {
        uint _totalPrice = getTotalPrice(_itemId);
        Item storage item = items[_itemId];
        require(_itemId > 0 && _itemId <= itemCount, "item doesn't exist");
        require(
            msg.value >= _totalPrice,
            "not enough ether to cover item price and market fee"
        );
        require(!item.sold, "item already sold");
        // pay seller and feeAccount
        item.seller.transfer(item.price);
        feeAccount.transfer(_totalPrice - item.price);
        // update item to sold
        item.sold = true;
        // transfer nft to buyer
        item.nft.safeTransferFrom(address(this), msg.sender, item.tokenId);

        // emit Bought event
        emit Bought(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            item.seller,
            msg.sender
        );
    }

    function cancelListing(
        uint _itemId,
        address _NFTaddress
    ) external payable nonReentrant onlyOwner(msg.sender) {
        delete (Listed_Items[_NFTaddress][_itemId]);
        // update item to cancelled
        Item storage item = items[_itemId];
        item.sold = false;
        emit Cancel(_itemId, _NFTaddress);
    }

    function updateListing(
        IERC721 _nft,
        uint _tokenId,
        uint _newprice,
        uint _oldprice
    ) external nonReentrant onlyOwner(msg.sender) {
        require(
            _newprice > 0 || _newprice != _oldprice,
            "Price should be above 0 and not same as the old price"
        );

        // add new item to items mapping
        items[itemCount] = Item(
            itemCount,
            _nft,
            _tokenId,
            _newprice,
            payable(msg.sender),
            false
        );
        // increment itemCount
        itemCount++;
        // transfer nft
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        // emit Offered event
        emit Offered(itemCount, address(_nft), _tokenId, _newprice, msg.sender);
    }

    function Withdraw() external {
        uint amount = AmountEarned[msg.sender];
        require(amount <= 0, "not the correct amount");
        AmountEarned[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function getTotalPrice(uint _itemId) public view returns (uint) {
        return ((items[_itemId].price * (100 + feePercent)) / 100);
    }
}
