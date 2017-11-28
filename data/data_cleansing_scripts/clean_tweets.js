var fs = require("fs");

var tweetscorpus = fs.readFileSync("tweets.txt");
tweets = tweetscorpus.toString().split("\n");

for(var i = 0; i < tweets.length; i++){
	tweets[i] = clean(tweets[i]);
	console.log(tweets[i])
}

fs.writeFileSync("../tweets.txt", tweets.join("\n"));

// cleaning non ascii characters i.e weird unicode characters in tweets 

function clean(tweet){
	tweet = tweet.replace(/[^\x00-\x7F]/g, "");
	tweet = tweet.replace(/[^a-zA-Z ]/g, "")
	
	return tweet;
}
