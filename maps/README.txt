自定义地图目录
================

请将你制作或下载的地图文件放到本目录，例如：

  my_map.bsp
  my_map.wad          （如有）
  my_map.txt          （如有 overview）
  my_map_detail.txt   （如有）

启动容器时请挂载：

  -v "$(pwd)/maps:/opt/steam/custom_maps"

entrypoint 会把文件复制到服务器的 cstrike/maps/ 中
（不会覆盖镜像自带的官方地图）。

使用自定义地图开服示例：

  docker run ... -e START_MAP=my_map ...

地图名不要带 .bsp 后缀。

如需加入地图循环，请编辑 config/mapcycle.txt，把地图名加进去。
