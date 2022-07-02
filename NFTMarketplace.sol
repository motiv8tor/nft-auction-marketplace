// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTCollection.sol";

contract NFTMarketplace {
    uint256 public offerCount;
    uint256 marketFee = 250;
    uint256 donationLimit = 0.005 ether; // per percentage
    mapping(uint256 => _Offer) public offers;
    mapping(address => uint256) public userFunds;
    mapping(uint256 => Auction) public nftAuctions;
    mapping(uint256 => uint256) public donations;
    NFTCollection nftCollection;
    address private _owner;

    struct _Offer {
        uint256 offerId;
        uint256 id;
        uint256 price;
        address user;
        bool fulfilled;
        bool cancelled;
    }

    struct Auction {
        //map token ID to
        uint256 buyNowPrice;
        uint256 nftHighestBid;
        uint256 auctionEnd;
        address nftHighestBidder;
        address nftSeller;
    }

    

   

    constructor(address _nftCollection) {
        nftCollection = NFTCollection(_nftCollection);
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    function _marketTransfer(
        uint256 _price,
        uint256 _tokenId,
        address _receiver
    ) internal {
        require(_price > 0, "No fund to process");
        uint256 royalty = nftCollection.royalty(_tokenId);
        address inventor = nftCollection.inventor(_tokenId);
        userFunds[_owner] += (_price * marketFee) / 10000;
        uint256 roayltyFund = (_price * royalty) / 10000;
        uint256 loan = ((donationLimit - donations[_tokenId]) * royalty) / 100;
        if (loan >= roayltyFund) {
            donations[_tokenId] += (roayltyFund * 100) / royalty;
            userFunds[_owner] += roayltyFund;
            roayltyFund = 0;
        } else {
            roayltyFund -= loan;
            userFunds[_owner] += loan;
            donations[_tokenId] = donationLimit;
        }

        userFunds[inventor] += roayltyFund;
        userFunds[_receiver] +=
            _price -
            (_price * (marketFee + royalty)) /
            10000;
    }

    function makeOffer(uint256 _id, uint256 _price) public {
        nftCollection.transferFrom(msg.sender, address(this), _id);
        offerCount++;
        offers[offerCount] = _Offer(
            offerCount,
            _id,
            _price,
            msg.sender,
            false,
            false
        );
        
    }

    function fillOffer(uint256 _offerId) public payable {
        _Offer storage _offer = offers[_offerId];
        require(_offer.offerId == _offerId, "The offer must exist");
        require(
            _offer.user != msg.sender,
            "The owner of the offer cannot fill it"
        );
        require(!_offer.fulfilled, "An offer cannot be fulfilled twice");
        require(!_offer.cancelled, "A cancelled offer cannot be fulfilled");

        require(
            msg.value + userFunds[msg.sender] >= _offer.price,
            "The ETH amount should match with the NFT Price"
        );
        nftCollection.transferFrom(address(this), msg.sender, _offer.id);
        _offer.fulfilled = true;
        _marketTransfer(_offer.price, _offer.id, _offer.user);
        userFunds[msg.sender] -= _offer.price - msg.value;
       
    }

    function cancelOffer(uint256 _offerId) public {
        _Offer storage _offer = offers[_offerId];
        require(_offer.offerId == _offerId, "The offer must exist");
        require(
            _offer.user == msg.sender,
            "The offer can only be canceled by the owner"
        );
        require(
            _offer.fulfilled == false,
            "A fulfilled offer cannot be cancelled"
        );
        require(
            _offer.cancelled == false,
            "An offer cannot be cancelled twice"
        );
        nftCollection.transferFrom(address(this), msg.sender, _offer.id);
        _offer.cancelled = true;
       
    }

    function updateOffer(uint256 _offerId, uint256 _price) public {
        _Offer storage _offer = offers[_offerId];
        require(_offer.offerId == _offerId, "The offer must exist");
        require(
            _offer.user == msg.sender,
            "The offer can only be updated by the owner"
        );
        require(
            _offer.fulfilled == false,
            "A fulfilled offer cannot be updated"
        );

        _offer.price = _price;
      
    }

    function getAuctions()
        external
        view
        returns (Auction[] memory, uint256[] memory)
    {
        uint256 total = nftCollection.totalSupply();
        Auction[] memory result = new Auction[](total);
        uint256[] memory tokenIds = new uint256[](total);
        for (uint256 i = 0; i < total; i++) {
            tokenIds[i] = nftCollection.tokenByIndex(i);
            result[i] = nftAuctions[tokenIds[i]];
        }
        return (result, tokenIds);
    }

    function makeAuction(
        uint256 _tokenId,
        uint256 _price,
        uint256 period
    ) public {
        nftCollection.transferFrom(msg.sender, address(this), _tokenId);

        nftAuctions[_tokenId].buyNowPrice = _price;
        nftAuctions[_tokenId].auctionEnd = block.timestamp + period * 1 hours;
        nftAuctions[_tokenId].nftSeller = msg.sender;

     
    }

    function cancelAuction(uint256 _tokenId) public {
        require(
            nftAuctions[_tokenId].nftSeller == msg.sender,
            "The only owner of the auction can cancel it"
        );
        require(
            nftAuctions[_tokenId].nftHighestBid <
                nftAuctions[_tokenId].buyNowPrice,
            "The bid must not exist"
        );
        nftCollection.transferFrom(address(this), msg.sender, _tokenId);

        nftAuctions[_tokenId].buyNowPrice = 0;
        nftAuctions[_tokenId].auctionEnd = 0;
        nftAuctions[_tokenId].nftSeller = address(0);

       
    }

    function settleAuction(uint256 _tokenId) public {
        require(
            nftAuctions[_tokenId].nftSeller != address(0),
            "The auction must exist"
        );
        require(
            nftAuctions[_tokenId].auctionEnd <= block.timestamp,
            "Auction should be ended"
        );

       

        if (nftAuctions[_tokenId].nftHighestBidder != address(0)) {
            _marketTransfer(
                nftAuctions[_tokenId].nftHighestBid -
                    nftAuctions[_tokenId].nftHighestBid /
                    10,
                _tokenId,
                nftAuctions[_tokenId].nftSeller
            );
        }

        nftAuctions[_tokenId].buyNowPrice = 0;
        nftAuctions[_tokenId].auctionEnd = 0;
        nftAuctions[_tokenId].nftSeller = address(0);
        nftAuctions[_tokenId].nftHighestBid = 0;
        nftAuctions[_tokenId].nftHighestBidder = address(0);
    }

    function makeBid(uint256 _tokenId) public payable {
        require(
            nftAuctions[_tokenId].nftSeller != address(0),
            "The auction must exist"
        );
        require(
            nftAuctions[_tokenId].auctionEnd > block.timestamp,
            "Auction has ended"
        );
        require(
            nftAuctions[_tokenId].nftSeller != msg.sender,
            "The owner of the auction cannot bid it"
        );
        uint256 limit = nftAuctions[_tokenId].nftHighestBid;
        if (limit > nftAuctions[_tokenId].buyNowPrice) {
            if (limit / 10 > 0.01 ether) limit = (limit * 11) / 10;
            else limit += 0.01 ether;
        } else limit = nftAuctions[_tokenId].buyNowPrice;
        require(
            msg.value >= limit,
            "The ETH amount should be more than 110% of NFT highest bid Price"
        );

        address _receiver = nftAuctions[_tokenId].nftHighestBidder;
        if (_receiver == address(0)) {
            _receiver = nftAuctions[_tokenId].nftSeller;
            _marketTransfer(msg.value / 10, _tokenId, _receiver);
        } else
            userFunds[_receiver] +=
                nftAuctions[_tokenId].nftHighestBid -
                nftAuctions[_tokenId].nftHighestBid /
                10 +
                msg.value /
                10;

        nftAuctions[_tokenId].nftHighestBidder = msg.sender;
        nftAuctions[_tokenId].nftHighestBid = msg.value;
        if (nftAuctions[_tokenId].auctionEnd < block.timestamp + 10 minutes)
            nftAuctions[_tokenId].auctionEnd = block.timestamp + 10 minutes;

       
    }

    function cancelBid(uint256 _tokenId) public {
        require(
            nftAuctions[_tokenId].nftSeller != address(0),
            "The auction must exist"
        );
        require(
            nftAuctions[_tokenId].auctionEnd > block.timestamp,
            "Auction has ended"
        );
        require(
            msg.sender == nftAuctions[_tokenId].nftHighestBidder,
            "Only highest bidder can cancel the bid"
        );

        userFunds[msg.sender] =
            nftAuctions[_tokenId].nftHighestBid -
            nftAuctions[_tokenId].nftHighestBid /
            10;
        nftAuctions[_tokenId].nftHighestBidder = address(0);
        nftAuctions[_tokenId].nftHighestBid = 0;

      
    }

    function claimFunds() public {
        require(
            userFunds[msg.sender] > 0,
            "This user has no funds to be claimed"
        );
        payable(msg.sender).transfer(userFunds[msg.sender]);
        
        userFunds[msg.sender] = 0;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        _owner = newOwner;
    }

    function updateMarketFee(uint256 _fee) public onlyOwner {
        require(
            _fee >= 0 && _fee <= 1000,
            "Marketplace fee can not exceed 10% or negative"
        );
        marketFee = _fee;
    }

    function updateDonationLimit(uint256 _fee) public onlyOwner {
        require(
            _fee >= 0 && _fee <= 0.01 ether,
            "Donation fee can not exceed 0.01ether per 1% or negative"
        );
        donationLimit = _fee;
    }

    // Fallback: reverts if Ether is sent to this smart-contract by mistake
    fallback() external {
        revert();
    }
}