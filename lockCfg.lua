--参数配置存放文件
module(...,package.seeall)
--string.format("%x",0x6ff1007)
lockParas = {
["AngleValve"]     = 0,             --角度检测全局变量
["ElectricityADC"] = 238,           --电量值
["ParkingStatus"]  = 0,             --车位状态全局变量 0：无车 1：有车
["LockStatus"]     = 0,             --锁上锁开锁状态
["PreLockStatus"]  = 0,             --上一次锁上锁开锁状态
["AbnormalSign"]   = 0,             --异常标志        0：正常 1：异常
["AutomaticLockingTime"] = 60,     --有车自动上锁
["AutoLockTime"] = 30,               --TMN 启用自动上锁标志且停车超过AutomaticLockingTime后从有车到无车多久自动上锁时长参数
["OpenLockTime"] = 20,               --TMC 启用自动上锁标志且开锁后一直无停车多久自动上锁时长参数
["LockDeviceID"] = string.format("%x",0x6ff1007)  --设备ID
}