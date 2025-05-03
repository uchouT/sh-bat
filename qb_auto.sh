#!/bin/bash
torrent_name=$1
content_dir=$2
root_dir=$3
save_dir=$4
files_num=$5
torrent_size=$6
torrent_hash=$7
torrent_type=$8

# if [ ${torrent_type} == "ani-rss" ]
# then
# 	 exit 0
# fi

qb_version="4.5.4"
qb_username="admin"
qb_password="password"
qb_web_url="http://localhost:8080"
log_dir="/root/qblog"
rclone_dest="od"
rclone_parallel="5"
uploaded_flag="rcloned"
alist_host="http://localhost:5244"
alist_token=""


if [ ! -d ${log_dir} ]
then
	mkdir -p ${log_dir}
fi

version=$(echo $qb_version | grep -P -o "([0-9]\.){2}[0-9]" | sed s/\\.//g)

function qb_login(){
	if [ "${version}" -gt 404 ]
	then
		qb_v="1"
		cookie=$(curl -i --header "Referer: ${qb_web_url}" --data "username=${qb_username}&password=${qb_password}" "${qb_web_url}/api/v2/auth/login" | grep -P -o 'SID=\S{32}')
		if [ -n "${cookie}" ]
		then
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] 登录成功！cookie:${cookie}" >> ${log_dir}/qb_login.log

		else
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] 登录失败！" >> ${log_dir}/qb_login.log
		fi
	elif [[ ${version} -le 404 && ${version} -ge 320 ]]
	then
		qb_v="2"
		cookie=$(curl -i --header "Referer: ${qb_web_url}" --data "username=${qb_username}&password=${qb_password}" "${qb_web_url}/login" | grep -P -o 'SID=\S{32}')
		if [ -n "${cookie}" ]
		then
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] 登录成功！cookie:${cookie}" >> ${log_dir}/qb_login.log
		else
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] 登录失败" >> ${log_dir}/qb_login.log
		fi
	elif [[ ${version} -ge 310 && ${version} -lt 320 ]]
	then
		qb_v="3"
		echo "陈年老版本，请及时升级"
		exit
	else
		qb_v="0"
		exit
	fi
}

function alist_refresh() {
  local path="$1"
  local url="${alist_host}/api/fs/list"
  local json
  json=$(jq -n --argjson refresh true --arg path "$path" '{refresh: $refresh, path: $path}')

  local res
  res=$(curl -s -X POST "$url" \
    -H "Authorization: ${alist_token}" \
    -d "$json")
  local code
  code=$(echo "$res" | jq -r '.code')
  if [ "$code" -eq 200 ]
  then
    	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Alist: $path 刷新成功！" >> ${log_dir}/alist.log
  else
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Alist: $path 刷新失败！" >> ${log_dir}/alist.log
  fi
}


function rclone_copy(){
	local_dir="${content_dir}"
	if [ "${type}" == "file" ]
	then
		if [ "${torrent_type}" == "ani-rss" ]
		then
			target_dir=${save_dir}
		else
			target_dir=${save_dir#"$HOME"}
		fi
	elif [ "${type}" == "dir" ]
	then
		local_dir="${local_dir}/"
		target_dir="${content_dir#"$HOME"}/"
	fi
	rclone -v copy --transfers ${rclone_parallel} --log-file  "${log_dir}"/qbauto_copy.log \
	"${local_dir}" "${rclone_dest}:${target_dir}" \
	--local-encoding None --onedrive-encoding None
	if [ "${torrent_type}" == "ani-rss" ]
	then
		alist_refresh "/Media/Bangumi"
		alist_refresh "${target_dir}"
	fi
}

function qb_uploaded(){
	if [ ${qb_v} == "1" ]
	then
		curl -X POST -d "hashes=${torrent_hash}&tags=${uploaded_flag}" "${qb_web_url}/api/v2/torrents/addTags" --cookie "${cookie}"
	elif [ ${qb_v} == "2" ]
	then
		curl -X POST -d "hashes=${torrent_hash}&category=${uploaded_flag}" "${qb_web_url}/command/setCategory" --cookie "${cookie}"
	else
		echo "qb_v=${qb_v}" >> ${log_dir}/qb.log
	fi
}

if [ -f "${content_dir}" ]
then
   type="file"
elif [ -d "${content_dir}" ]
then 
   type="dir"
else
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] 未知类型，取消上传" >> ${log_dir}/qb.log
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 类型：${type}" >> ${log_dir}/qb.log
rclone_copy
qb_login
qb_uploaded

echo "种子名称：${torrent_name}" >> ${log_dir}/qb.log
echo "内容路径：${content_dir}" >> ${log_dir}/qb.log
echo "根目录：${root_dir}" >> ${log_dir}/qb.log
echo "保存路径：${save_dir}" >> ${log_dir}/qb.log
echo "文件数：${files_num}" >> ${log_dir}/qb.log
echo "文件大小：${torrent_size}Bytes" >> ${log_dir}/qb.log
echo "HASH:${torrent_hash}" >> ${log_dir}/qb.log
echo "Cookie:${cookie}" >> ${log_dir}/qb.log
echo -e "-------------------------------------------------------------\n" >> ${log_dir}/qb.log
