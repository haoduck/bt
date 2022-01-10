# 宝塔历史版本

官方版本，仅分发  

## tip

7.4.2有pma重大安全漏洞  

7.4.5起强制绑定账号  

## 安装命令
Linux面板7.8.0安装命令：  
Centos安装命令：  
```yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh```
试验性Centos/Ubuntu/Debian安装命令 独立运行环境（py3.7） 可能存在少量兼容性问题 不断优化中    
```curl -sSO http://download.bt.cn/install/install_panel.sh && bash install_panel.sh```
Ubuntu/Deepin安装命令：  
```wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh```
Debian安装命令：  
```wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && bash install.sh```
Fedora安装命令:  
```wget -O install.sh http://download.bt.cn/install/install_6.0.sh && bash install.sh```

Linux面板7.8.0升级命令： 
```curl http://download.bt.cn/install/update6.sh|bash```


aaPanel is developed based on Centos, we recommend using Centos to install it  
Centos :  
```yum install -y wget && wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh && bash install.sh forum```
The experimental Centos/Ubuntu/Debian/Fedora installation command supports ipv6. Note that this command is executed with root privileges (Centos8 is supported)  
```curl -sSO http://www.aapanel.com/script/new_install_en.sh && bash new_install_en.sh forum```
Ubuntu/Deepin :  
```wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && sudo bash install.sh forum```
Debian :  
```wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && bash install.sh forum```

Linux面板5.9（稳定版）安装命令  
Centos安装命令：  
```yum install -y wget && wget -O install.sh http://download.bt.cn/install/install.sh && sh install.sh```
Ubuntu/Deepin安装命令：
```wget -O install.sh http://download.bt.cn/install/install-ubuntu.sh && sudo bash install.sh```
Debian安装命令：  
```wget -O install.sh http://download.bt.cn/install/install-ubuntu.sh && bash install.sh```
Fedora安装命令:  
```wget -O install.sh http://download.bt.cn/install/install.sh && bash install.sh```

宝塔5.x切换免费版和专业版  
切换至免费版：  
```wget -O update.sh http://download.bt.cn/install/update.sh && bash update.sh free```
切换至专业版：  
```wget -O update.sh http://download.bt.cn/install/update.sh && bash update.sh pro```

## Log

2022/01/10 补档下列几个pro的包  
```
http://download.bt.cn/install/update/LinuxPanel-5.8.8_pro.zip
http://download.bt.cn/install/update/LinuxPanel-5.8.9_pro.zip
http://download.bt.cn/install/update/LinuxPanel-5.9.0_pro.zip
http://download.bt.cn/install/update/LinuxPanel-5.9.1_pro.zip
http://download.bt.cn/install/update/LinuxPanel-5.9.2_pro.zip
http://download.bt.cn/install/update/LinuxPanel-6.0.1_pro.zip
http://download.bt.cn/install/update/LinuxPanel-6.0.2_pro.zip
http://download.bt.cn/install/update/LinuxPanel-6.0.3_pro.zip
http://download.bt.cn/install/update/LinuxPanel-6.0.4_pro.zip
```

新增aapanel的6.8.19
aapanel所有版本都是同一个链接，所以没有旧版本了(替掉了旧版)  
```
http://node.aapanel.com/install/src/panel6_en.zip
```
