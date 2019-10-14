#!/bin/bash

function lack_of_necessary_param() {
  echo "-vオプションは必須オプションです。-vオプションを必ず使用してください。"
  exit 1
}

function invalid_version() {
  echo "バージョンを正しく入力してください。(形式: X.X.X)"
  exit 1
}

CMDNAME=`basename $0`

while getopts rsv: OPT
do
  case $OPT in
    "r" ) FLG_R="true" ;;
    "s" ) FLG_S="true" ;;
    "v" ) FLG_V="true" ; VALUE_V="$OPTARG" ;;
      * ) echo "Usage: $CMDNAME [-r] [-s] [-v VALUE]" 1>&2
          exit 1 ;;
  esac
done

if [ "$FLG_V" != "true" ]; then
  ### -vオプションがない場合はエラー
  lack_of_necessary_param
fi

if [[ $VALUE_V =~ [0-9]\.[0-9]\.[0-9]$ ]]; then
  echo "$VALUE_V"
else
  ### バージョンが正しく入力されてない場合はエラー
  invalid_version 
fi

set -x
trap read debug

## 1. サービス停止
sudo systemctl stop mastodon-web.service mastodon-sidekiq.service mastodon-sidekiq-default.service mastodon-streaming.service

## 2. ソースの取り込み
### 公式からpull
cd /home/mastodon/live
echo `pwd`
git checkout upstream_master
git pull

### 公式とfork先をマージ
git checkout master
git merge --no-ff upstream_master

if [ "$FLG_R" != "true" -a "$FLG_S" = "true" ]; then
  ### fork先のmasterにpush
  git push origin master
  git push origin --tags
fi

if [ "$FLG_R" != "true" ]; then
  ### 最新のブランチをcheckout
  git checkout -b v"$VALUE_V" refs/tags/v"$VALUE_V"
else
  git checkout v"$VALUE_V"
fi

## 3. Mastodon更新
### 依存パッケージの更新
bundle install
yarn install

### プリコンパイル
export RAILS_ENV=production
bundle exec rails db:migrate
bundle exec rails assets:precompile

## 4. サービス開始
sudo systemctl start mastodon-web.service mastodon-sidekiq.service mastodon-sidekiq-default.service mastodon-streaming.service
