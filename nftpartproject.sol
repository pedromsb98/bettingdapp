// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./fullgamechatgptbien.sol";

contract NFTmarket is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint public mintPrice = 0.001 ether;
    uint public maxSupply;
    uint public currentSupply = totalSupply();
    bool public mintActicated;
    string baseURI = 'ipfs://QmXQ6SqYvE6pbWGohQJz1VLVBPA43NnH6xZMfncT3ufGMF/';

    mapping(address => uint) public mintPerWallet;

    BNBPriceBetting public bnbPriceBetting;

    constructor(address _bnbPriceBetting) payable ERC721('Nocturnal creatures', 'NC') {
        maxSupply = 17;
        bnbPriceBetting = BNBPriceBetting(_bnbPriceBetting);
    }

    function activeMint() public onlyOwner {
        mintActicated = !mintActicated;
    }

    function setMaxSupply(uint _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    function setMintPrice(uint _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function _baseURI() internal override view returns(string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns(string memory) {
        _requireMinted(tokenId); //функция ERC721 - проверяет заминтился ли токен
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
                : "";
    }

    modifier required() {
        require(mintActicated, 'Mint is not activated');
        require(mintPerWallet[msg.sender] < 1, 'You have already minted');
        require(msg.value == mintPrice, 'You pay incorrect amount of money. Pay 0.001 tBNB');
        require(maxSupply > totalSupply(), 'This NFT collecction Sold Out');
        _;
    }

    modifier onlyWhitelisted() {
        require(bnbPriceBetting.whitelist(msg.sender), "You are not whitelisted");
        _;
    }

    function mintByTokenId(uint8 _tokenId) external payable required onlyWhitelisted {
        mintPerWallet[msg.sender]++;
        _safeMint(msg.sender, _tokenId);
    }

    function mintByLine() external payable required onlyWhitelisted {
        mintPerWallet[msg.sender]++;
        uint tokenId = currentSupply;
        while (_exists(tokenId)) {
            tokenId++;
            currentSupply++;
        }

        currentSupply++;
        _safeMint(msg.sender, tokenId);
    }

    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }
}
