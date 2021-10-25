package com.github.sachin.spookin.modules.curses;

import java.util.Arrays;
import java.util.List;

import com.comphenix.protocol.PacketType;
import com.comphenix.protocol.ProtocolLibrary;
import com.comphenix.protocol.events.PacketAdapter;
import com.comphenix.protocol.events.PacketContainer;
import com.comphenix.protocol.events.PacketEvent;
import com.github.sachin.spookin.Spookin;

import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.entity.Player;
import org.bukkit.persistence.PersistentDataType;


public class SicknessCurse extends BaseCurse{

    public SicknessCurse(CurseModule instance) {
        super("&eSickness","sickness", Arrays.asList("&7Misindicates the health bar"), Spookin.getKey("sickness-curse-key"),Arrays.asList(Material.GHAST_TEAR,Material.GUNPOWDER), instance);
        ProtocolLibrary.getProtocolManager().addPacketListener(new PacketAdapter(instance.getPlugin(),PacketType.Play.Server.UPDATE_HEALTH){
            @Override
            public void onPacketSending(PacketEvent event) {
                Player player = event.getPlayer();
                PacketContainer packet = event.getPacket();
                if(player.getPersistentDataContainer().has(curseKey, PersistentDataType.STRING) && !packet.getMeta("isUpdatePacket").isPresent()){
                    packet.getFloat().write(0, 20F);
                    
                }
            }
        });
    }


    @Override
    public void onRemove(Player player) {
        StarvationCurse.updateHunger(player,true);
    }

    @Override
    public void applyCurse(Player player) {
        super.applyCurse(player);
        StarvationCurse.updateHunger(player, false);
    }
    
}
