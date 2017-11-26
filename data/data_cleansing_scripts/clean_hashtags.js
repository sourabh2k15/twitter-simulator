var fs = require("fs");

var hashtags_corpus = fs.readFileSync("hashtags.txt");
hashtags = hashtags_corpus.toString().split("\n");

hashtags.pop();

for(var i = 0; i < hashtags.length; i++){
	hashtags[i] = "#"+ hashtags[i];
	console.log(hashtags[i])
}

fs.writeFileSync("../hashtags.txt", hashtags.join("\n"));
