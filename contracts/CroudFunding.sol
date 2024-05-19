// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
 import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 
 import "@openzeppelin/contracts/utils/Counters.sol";
 import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// contract ReputationToken is ERC20, Ownable {
//     constructor() ERC20("ReputationToken", "RPT") {}

//     function mint(address to, uint256 amount) external onlyOwner {
//         _mint(to, amount);
//     }

//     function burn(address from, uint256 amount) external onlyOwner {
//         _burn(from, amount);
//     }
// }



contract WikipediaApp {

    address payable owner;


    struct User {
        address wallet;
    }


    struct Article {
        string title;
        string content;
        uint256 upvotes;
        uint256 downvotes;
        bool posted;
        uint256 createdAt;
        uint256[] updateIds;
        uint256 articleId;
        address creator;
    }

    struct Update {
        string newContent;
        uint256 upvotes;
        uint256 downvotes;
        bool applied;
        uint256 createdAt;
        uint256 articleId;
        uint256 updateid;
    }

    mapping(uint256 => Article) public articles;
    mapping(address => User) public users;
    mapping(uint256 => Update) public updates;
    uint256 public articleCount = 0;
    uint256 public updateCount = 0;

    event ArticleCreated(uint256 indexed articleId, string title, address creator);
    event ArticlePosted(uint256 indexed articleId);
    event UpdateSubmitted(uint256 indexed articleId, uint256 indexed updateId);
    event UpdateApplied(uint256 indexed articleId, uint256 indexed updateId);
    event ArticleDeleted(uint256 indexed articleId);
    event ArticleUpvoted(uint256 indexed articleId);
    event ArticleDownvoted(uint256 indexed articleId);
    event ArticleUpvotedBeforePosting(uint256 indexed articleId);
    event ArticleDownvotedBeforePosting(uint256 indexed articleId);

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner of the contract can perform this action");
        _;
    }

    modifier articleExists(uint256 _articleId) {
        require(_articleId < articleCount, "Invalid article ID");
        _;
    }

    modifier updateExists(uint256 _updateId) {
        require(_updateId < updateCount, "Invalid update ID");
        _;
    }

    // constructor(address _reputationToken) ERC721("Article Owner", "MyArticle") {
    //     owner = payable(msg.sender);
    //     reputationToken = ReputationToken(_reputationToken);
    // }

    // function createToken(address sender) internal view returns(uint256){
    //     _tokenId.increment();
    //     uint256 newtokenId = _tokenId.current();
    //     users[sender] = User(sender, ReputationToken(newtokenId));
    //     users[sender].reputationToken.mint(sender, 0);
    // }

    function registerUser(address _wallet) public {
        require(_wallet != address(0), "Invalid wallet address");
        require(users[_wallet].wallet == address(0), "User already registered");
        // createToken(msg.sender);
        users[_wallet] = User(_wallet);
    }

    function getUserDetails(address _user) public view returns(address){
        return (users[_user].wallet);
    }

    function createArticle(string memory _title, string memory _content) public {
        articles[articleCount] = Article({
            title: _title,
            content: _content,
            upvotes: 0,
            downvotes: 0,
            posted: false,
            createdAt: block.timestamp,
            updateIds: new uint256[](0) ,
            articleId:articleCount,
            creator: msg.sender
        });
        emit ArticleCreated(articleCount, _title, msg.sender);
        articleCount++;
    }

    function submitUpdate(uint256 _articleId, string memory _newContent) public articleExists(_articleId) {
        uint256 _updateId = updateCount++;
        updates[_updateId] = Update({
            newContent: _newContent,
            upvotes: 0,
            downvotes: 0,
            applied: false,
            createdAt: block.timestamp,
            articleId: _articleId,
            updateid:_updateId
        });
        articles[_articleId].updateIds.push(_updateId);
        emit UpdateSubmitted(_articleId, _updateId);
         // Mint 5 RPT tokens to the update creator
    }

    function upvoteArticle(uint256 _articleId) public articleExists(_articleId) {
        Article storage article = articles[_articleId];
        article.upvotes++;
        emit ArticleUpvoted(_articleId);
        checkArticleForPosting(_articleId);
    }

    function downvoteArticle(uint256 _articleId) public articleExists(_articleId) {
        Article storage article = articles[_articleId];
        article.downvotes++;
        emit ArticleDownvoted(_articleId);
        checkArticleForPosting(_articleId);
    }

    function checkArticleForPosting(uint256 _articleId) internal {
        Article storage article = articles[_articleId];
        if (!article.posted && block.timestamp >= article.createdAt + 5 minutes) {
            if (article.upvotes > article.downvotes) {
                article.posted = true;
                article.downvotes = 0;
                article.upvotes = 0;
                emit ArticlePosted(_articleId);
            }
        }
    }

    function upvoteUpdate(uint256 _updateId) public updateExists(_updateId) {
        updates[_updateId].upvotes++;
        checkUpdateForApplying(_updateId);
    }

    function downvoteUpdate(uint256 _updateId) public updateExists(_updateId) {
        updates[_updateId].downvotes++;
        checkUpdateForApplying(_updateId);
    }

    function checkUpdateForApplying(uint256 _updateId) internal {
        Update storage update = updates[_updateId];
        if (!update.applied && block.timestamp >= update.createdAt + 5 minutes) {
            if (update.upvotes > update.downvotes) {
                update.applied = true;
                emit UpdateApplied(update.articleId, _updateId);

                // Append the content of the update to the article
                Article storage article = articles[update.articleId];
                article.content = string(abi.encodePacked(article.content, "\n", update.newContent));

                // Delete the update
                delete updates[_updateId];
            }
        }
    }

    function deleteArticle(uint256 _articleId) public articleExists(_articleId) {
        Article storage article = articles[_articleId];
        require(!article.posted, "Article already posted");
        require(block.timestamp >= article.createdAt + 5 minutes, "Article needs to wait for 5 minutes");
        require(article.downvotes > article.upvotes, "Downvotes must be greater than upvotes");
        delete articles[_articleId];
        emit ArticleDeleted(_articleId);
    }

    function getArticle(uint256 _articleId) public view returns (string memory, string memory, uint256, uint256, bool, uint256, address) {
        require(_articleId < articleCount, "Invalid article ID");
        Article memory article = articles[_articleId];
        return (
            article.title,
            article.content,
            article.upvotes,
            article.downvotes,
            article.posted,
            article.createdAt,
            article.creator
        );
    }

    function getArticleByTitle(string memory _title) public view returns (Article[] memory) {
            uint256 matchingCount = 0;
            for (uint256 i = 0; i < articleCount; i++) {
                if (keccak256(abi.encodePacked(articles[i].title)) == keccak256(abi.encodePacked(_title))) {
                    matchingCount++;
                }
            }

            Article[] memory matchingArticles = new Article[](matchingCount);
            uint256 j = 0;
            for (uint256 i = 0; i < articleCount; i++) {
                if (keccak256(abi.encodePacked(articles[i].title)) == keccak256(abi.encodePacked(_title))) {
                    matchingArticles[j] = articles[i];
                    j++;
                }
            }

            return matchingArticles;
        }


    function getUpdatesByArticleId(uint256 _articleId) public view returns (Update[] memory) {
    uint256 count = 0;
    for (uint256 i = 0; i < updateCount; i++) {
        if (updates[i].articleId == _articleId) {
            count++;
        }
    }
    Update[] memory result = new Update[](count);
    uint256 index = 0;
    for (uint256 i = 0; i < updateCount; i++) {
        if (updates[i].articleId == _articleId) {
            result[index] = updates[i];
            index++;
        }
    }
    return result;
}


    function viewPendingArticles() public view returns (Article[] memory) {
        uint256 pendingArticleCount = 0;
        for (uint256 i = 0; i < articleCount; i++) {
            Article memory article = articles[i];
            if ((!article.posted && (block.timestamp >= article.createdAt + 5 minutes && article.upvotes > article.downvotes)) || block.timestamp < article.createdAt + 5 minutes) {
                pendingArticleCount++;
            }
        }

        Article[] memory pendingArticles = new Article[](pendingArticleCount);
        uint256 index = 0;

        for (uint256 i = 0; i < articleCount; i++) {
            Article memory article = articles[i];
            if ((!article.posted && (block.timestamp >= article.createdAt + 5 minutes && article.upvotes > article.downvotes)) || block.timestamp < article.createdAt + 5 minutes) {
                pendingArticles[index] = article;
                index++;
            }
        }

        return pendingArticles;
    }

    function viewPendingUpdates() public view returns (Update[] memory) {
        uint256 pendingUpdateCount = 0;
        // Count the number of pending updates
        for (uint256 i = 0; i < updateCount; i++) {
            if (!updates[i].applied) {
                pendingUpdateCount++;
            }
        }
        // Initialize array to store pending updates
        Update[] memory pendingUpdates = new Update[](pendingUpdateCount);
        uint256 index = 0;
        // Populate the array with pending updates
        for (uint256 i = 0; i < updateCount; i++) {
            if (!updates[i].applied) {
                pendingUpdates[index] = updates[i];
                index++;
            }
        }
        return pendingUpdates;
    }
}
