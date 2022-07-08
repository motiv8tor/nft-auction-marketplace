// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTCollection is ERC721, ERC721Enumerable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    mapping(string => bool) private _tokenURIExists;

    struct Record {
        uint256 royalty;
        address inventor;
    }
    mapping(uint256 => Record) records;

    constructor() ERC721("Art Collection", "Art") {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return super.tokenURI(tokenId);
    }

    function safeMint(string memory _tokenURI, uint256 _royalty) public {
        require(bytes(_tokenURI).length > 0, "Invalid URI");
        require(!_tokenURIExists[_tokenURI], "The token URI should be unique");
        require(
            _royalty <= 10 && _royalty >= 1,
            "Royalty can not exceed 10% or negative"
        );
        uint256 _id = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        records[_id] = Record(_royalty, msg.sender);
        _safeMint(msg.sender, _id);
        _tokenURIExists[_tokenURI] = true;
    }

    function getRecord(uint256 tokenId) public view returns (uint256, address) {
        require(_exists(tokenId), "Query of non existent Record");
        Record memory record = records[tokenId];
        return (record.royalty, record.inventor);
    }

    function exist(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }
}
