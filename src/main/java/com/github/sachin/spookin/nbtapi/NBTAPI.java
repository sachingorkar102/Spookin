package com.github.sachin.spookin.nbtapi;

import com.github.sachin.spookin.nbtapi.nms.*;
import com.github.sachin.spookin.nbtapi.nms.nms1_17.NBTItem_1_17_R1;

import org.bukkit.plugin.java.JavaPlugin;

public class NBTAPI {

    public NMSHelper NMSHelper;

    public boolean loadVersions(JavaPlugin plugin,String version){
        if(version.equals("v1_17_R1")){
            NMSHelper = new NBTItem_1_17_R1(null);
            return true;
        }
        return false;
        
    }

    
}
