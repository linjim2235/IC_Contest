#!/bin/bash

# 定義輸入、輸出目錄和其他參數
input_dir="../../img"
output_dir="../../output"
input_prefix="0.raw"
output_prefix="0.raw"
# flag="-f 0 -s 0"
# flag="-f 7550144 -s 143452736" #10%
# flag="-f 11325216 -s 139677664" #15%
# flag="-f 15100288 -s 135902592" #20%
# flag="-f 18875360 -s 132127520" #25%
# flag="-f 22650432 -s 128352448" #30%
# flag="-f 26425504 -s 124577376"
# flag="-f 30200576 -s 120802304" #40%
# flag="-f 33975648 -s 117027232"
# flag="-f 37750720 -s 113252160" #50%
# flag="-f 41525792 -s 109477088"
flag="-f 45300864 -s 105702016" #60%
# flag="-f 47557392 -s 103445488" #63%
# flag="-f 49075936 -s 101926944"
# flag="-f 52851008 -s 98151872" #70%
output_file="./output.log"

# 初始化總計時間
total_read_file_time=0
total_compress_time=0
total_write_file_time=0
total_exewrite_time=0
total_total_time=0
total_process_time=0
total_compress_rate=0
# 遍歷從0到39
for i in $(seq 0 39); do
  input_file="${input_dir}/${i}.raw"
  output_file="${output_dir}/${i}.raw"
  
  # 執行命令並將輸出保存到變量
  output=$(./test.out -i "$input_file" -o "$output_file" $flag)
  # output=$(./compress_app.exe -i "$input_file" -o "$output_file" $flag)
  
  # 將輸出保存到文件
  # echo "$output" >> "$output_file"
  echo "$output" >> output_details.log

  # 提取各項時間和壓縮率
  read_file_time=$(echo "$output" | grep -oP "read file time  : \K[\d\.]+")
  compress_time=$(echo "$output" | grep -oP "compress time   : \K[\d\.]+")
  write_file_time=$(echo "$output" | grep -oP "write_file_time : \K[\d\.]+")
  exewrite_time=$(echo "$output" | grep -oP "exewrite time   : \K[\d\.]+")
  total_time=$(echo "$output" | grep -oP "total time      : \K[\d\.]+")
  process_time=$(echo "$output" | grep -oP "process time    : \K[\d\.]+")
  compress_rate=$(echo "$output" | grep -oP "compress rate   : \K[\d\.]+")

  # 累加各項時間和壓縮率
  total_read_file_time=$(echo "$total_read_file_time + $read_file_time" | bc)
  total_compress_time=$(echo "$total_compress_time + $compress_time" | bc)
  total_write_file_time=$(echo "$total_write_file_time + $write_file_time" | bc)
  total_exewrite_time=$(echo "$total_exewrite_time + $exewrite_time" | bc)
  total_total_time=$(echo "$total_total_time + $total_time" | bc)
  total_process_time=$(echo "$total_process_time + $process_time" | bc)
  total_compress_rate=$(echo "$total_compress_rate + $compress_rate" | bc)
done

# 計算平均時間和壓縮率
average_read_file_time=$(echo "scale=6; $total_read_file_time / 40" | bc)
average_compress_time=$(echo "scale=6; $total_compress_time / 40" | bc)
average_write_file_time=$(echo "scale=6; $total_write_file_time / 40" | bc)
average_exewrite_time=$(echo "scale=6; $total_exewrite_time / 40" | bc)
average_total_time=$(echo "scale=6; $total_total_time / 40" | bc)
average_process_time=$(echo "scale=6; $total_process_time / 40" | bc)
average_compress_rate=$(echo "scale=6; $total_compress_rate / 40" | bc)

# 輸出結果
echo "平均 read file time : $average_read_file_time 秒"
echo "平均 compress time  : $average_compress_time 秒"
echo "平均 write file time: $average_write_file_time 秒"
echo "平均 exewrite time  : $average_exewrite_time 秒"
echo "平均 total time     : $average_total_time 秒"
echo "平均 process time   : $average_process_time 秒"
echo "平均 compress rate  : $average_compress_rate %"

