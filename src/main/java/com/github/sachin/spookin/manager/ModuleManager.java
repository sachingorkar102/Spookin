package com.github.sachin.spookin.manager;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import com.github.sachin.spookin.BaseModule;
import com.github.sachin.spookin.Spookin;
import com.github.sachin.spookin.modules.candies.CandyModule;
import com.github.sachin.spookin.modules.curses.CurseModule;
import com.github.sachin.spookin.modules.jackolauncher.JackOLauncherModule;
import com.github.sachin.spookin.modules.monsterbox.MonsterBoxModule;
import com.github.sachin.spookin.modules.scarecrow.ScareCrowModule;
import com.github.sachin.spookin.modules.spookiermobs.SpookierMobsModuler;
import com.github.sachin.spookin.modules.trickortreatbasket.TrickOrTreatBasketModule;
import com.github.sachin.spookin.utils.ConfigUpdater;

public class ModuleManager {

    private Spookin plugin;
    private List<BaseModule> moduleList = new ArrayList<>();


    public ModuleManager(Spookin plugin){
        this.plugin = plugin;
    }

    public void load(){
        reload(false);
    }


    public void reload(){
        reload(true);
    }

    private void reload(boolean unregister){
        plugin.saveDefaultConfig();
        File configFile = new File(plugin.getDataFolder(),"config.yml");
        try {
            ConfigUpdater.update(plugin, "config.yml", configFile, new ArrayList<>(),unregister);
        } catch (IOException e) {
            plugin.getLogger().warning("Error occured while updating config.yml");
            e.printStackTrace();
        }
        plugin.reloadConfig();
        int registered = 0;
        for(BaseModule module : getModuleList()){
            try {
                module.reload();
                if(unregister){
    
                    if(module.registered){
                        module.unregister();
                    }
                }
                if(module.shouldEnable()){
                    module.register();
                    
                    registered++;
                }
            } catch (Exception e) {
                plugin.getLogger().info("Error occured while registering "+module.getName()+" tweak..");
                plugin.getLogger().info("Report this error on discord or at spigot page in discussion section.");
                e.printStackTrace();
                
            }
        }
        plugin.getLogger().info("Registered "+registered+" modules successfully");
        if(unregister){
            plugin.getLogger().info("Spookin reloaded successfully");
        }
        else{
            plugin.getLogger().info("Spookin loaded successfully");
        }
    }



    public List<BaseModule> getModuleList() {
        if(moduleList.isEmpty()){
            moduleList.add(new CurseModule());
            moduleList.add(new ScareCrowModule());
            moduleList.add(new MonsterBoxModule());
            moduleList.add(new TrickOrTreatBasketModule());
            moduleList.add(new CandyModule());
            moduleList.add(new JackOLauncherModule());
            moduleList.add(new SpookierMobsModuler());
        }
        return moduleList;
    }


    public BaseModule getModuleFromName(String name){
        for(BaseModule m : getModuleList()){
            if(m.getName().equalsIgnoreCase(name)){
                return m;
            }
        }
        return null;
    }


    public boolean isModuleEnabled(String name){
        BaseModule module = getModuleFromName(name);
        if(module != null){
            return module.registered;
        }
        return false;
    }
    
}
