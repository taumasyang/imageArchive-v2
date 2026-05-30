#!/bin/zsh
# version 2.0

local -i idx=${1:-0}
(( idx > 6 )) && print -u2 -- 'index too large' && return $idx
local -a mkt=(JA-JP ZH-CN EN-IN DE-DE ES-ES FR-FR IT-IT EN-GB PT-BR EN-CA EN-US)
local metadata=$(curl -fsSL 'https://www.bing.com/hp/api/model?mkt='${^mkt} | jq -c '.MediaContents['$idx'] | {
	name: .Name,
	market: .Market,
	hash: .Hash,
	startdate: .Ssd,
	headline: .ImageContent.Headline,
	title: .ImageContent.Title,
	description: .ImageContent.Description,
	quickfact: .ImageContent.QuickFact.MainText,
	copyright: .ImageContent.Copyright,
	urlbase: (.ImageContent.Image.Url | sub("_[^_]+$"; "_UHD.jpg"))
}')
for ((i=0; i<$#mkt; i++)) do
	jq -s --tab ".[$i]" <<< $metadata >> metadata/$mkt[$((i+1))].jsonl
done
local -A targets=($(jq -r '.name, .urlbase' <<< $metadata))
local -a curlargs=()
mkdir -p img
for k v in ${(@kv)targets}
do curlargs+=(-C - -o img/$k.jpg https://www.bing.com$v)
done
(($#curlargs)) && until curl -fsSLZ $curlargs; do :; done
local startdate=$(jq -rs '.[0].startdate' <<< $metadata)
startdate=$startdate[1,4]-$startdate[5,6]-$startdate[7,8]T08:00:00Z
git add metadata
GIT_AUTHOR_DATE=$startdate GIT_COMMITTER_DATE=$startdate git commit -m "Fetch: $startdate[1,10]"
(($#1)) || git push
