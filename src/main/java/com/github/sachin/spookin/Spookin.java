package com.github.sachin.spookin;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Random;

import com.github.sachin.spookin.commands.CommandManager;
import com.github.sachin.spookin.manager.ModuleManager;
import com.github.sachin.spookin.nbtapi.NBTAPI;
import com.github.sachin.spookin.nbtapi.nms.NMSHelper;
import com.github.sachin.spookin.utils.ConfigUpdater;
import com.github.sachin.spookin.utils.Items;
import com.github.sachin.spookin.utils.Message;

import org.bukkit.NamespacedKey;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.plugin.java.JavaPlugin;

public final class Spookin extends JavaPlugin {

    private static Spookin plugin;
    public boolean isRunningPaper;
    public boolean isProtocolLibEnabled;
    
    private Items items;
    private ModuleManager moduleManager;
    private Message messageManager;
    private NMSHelper nmsHelper;
    private String mcVersion;
    public final Random RANDOM = new Random();


    @Override
    public void onEnable() {
        plugin = this;
        if(getServer().getPluginManager().isPluginEnabled("ProtocolLib")) {
            isProtocolLibEnabled = true;
            getLogger().info("Running ProtocolLib..");
        }
        else isProtocolLibEnabled = false;
        try {
            Class.forName("com.destroystokyo.paper.utils.PaperPluginLogger");
            this.isRunningPaper = true;
            getLogger().info("Running papermc..");
        } catch (ClassNotFoundException e) {
            this.isRunningPaper = false;
        }
        this.mcVersion = plugin.getServer().getClass().getPackage().getName().split("\\.")[3];
        NBTAPI nbtapi = new NBTAPI();
        if(!nbtapi.loadVersions(plugin,mcVersion)){
            getLogger().warning("Running incompataible version, stopping spookin");
            this.getServer().getPluginManager().disablePlugin(this);
            return;
        }
        this.saveDefaultConfig();
        this.reloadConfig();
        this.messageManager = new Message();
        this.nmsHelper = nbtapi.NMSHelper;
        reload(true);
        this.moduleManager = new ModuleManager(plugin);
        moduleManager.load();
        CommandManager commandManager = new CommandManager(plugin); 
        getCommand("spookin").setExecutor(commandManager);
        getCommand("spookin").setTabCompleter(commandManager);
    }

    @Override
    public void onDisable() {
        super.onDisable();
        for(BaseModule module : getModuleManager().getModuleList()){
            if(module.registered){
                module.onDisable();
            }
        }
    }


    public void reload(boolean firstLoad){
        this.items = new Items(this);
        if(!firstLoad){
            this.moduleManager.reload();
        }
        this.messageManager = new Message();

    }

    public FileConfiguration getConfigFromFile(String fileName){
        File file = new File(getDataFolder(),fileName);
        if(!file.exists()){
            saveResource(fileName, true);
        }
        else{
            updateFile(fileName, file);
        }
        return YamlConfiguration.loadConfiguration(file);
    }

    public void updateFile(String fileName,File toUpdate){
        try {
            ConfigUpdater.update(plugin, fileName, toUpdate, new ArrayList<>(),true);
        } catch (IOException e) {
            getLogger().warning("Error occured while updating "+fileName+"...");
            e.printStackTrace();
        }
    }


    public static Spookin getPlugin() {
        return plugin;
    }

    public static NamespacedKey getKey(String key){
        return new NamespacedKey(plugin, key);
    }

    public ModuleManager getModuleManager() {
        return moduleManager;
    }

    public NMSHelper getNmsHelper() {
        return nmsHelper;
    }

    public Message getMessageManager() {
        return messageManager;
    }

    public Items getItemFolder() {
        return items;
    }

}
