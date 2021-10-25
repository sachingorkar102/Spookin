package com.github.sachin.spookin.modules.curses;

import java.lang.reflect.InvocationTargetException;
import java.util.Arrays;

import com.comphenix.protocol.PacketType;
import com.comphenix.protocol.ProtocolLibrary;
import com.comphenix.protocol.events.PacketAdapter;
import com.comphenix.protocol.events.PacketContainer;
import com.comphenix.protocol.events.PacketEvent;
import com.github.sachin.spookin.Spookin;

import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.persistence.PersistentDataType;

public class StarvationCurse extends BaseCurse{

    public StarvationCurse(CurseModule instance) {
        super("&eStarvation","starvation", Arrays.asList("&7Misindicates the hunger bar"), Spookin.getKey("starvation-curse-key"),Arrays.asList(Material.ROTTEN_FLESH,Material.GUNPOWDER), instance);
        ProtocolLibrary.getProtocolManager().addPacketListener(new PacketAdapter(instance.getPlugin(),PacketType.Play.Server.UPDATE_HEALTH){
            @Override
            public void onPacketSending(PacketEvent event) {
                Player player = event.getPlayer();
                PacketContainer packet = event.getPacket();
                if(player.getPersistentDataContainer().has(curseKey, PersistentDataType.STRING) && !packet.getMeta("isUpdatePacket").isPresent()){
                    packet.getIntegers().write(0, 20);
                }
            }
        });
    }

    public static void updateHunger(Player player,boolean isCustom){
        PacketContainer packet = new PacketContainer(PacketType.Play.Server.UPDATE_HEALTH);
        if(isCustom){
            packet.setMeta("isUpdatePacket", true);
        }
        packet.getFloat().write(0, (float)player.getHealth());
        packet.getFloat().write(1, player.getSaturation());
        packet.getIntegers().write(0, player.getFoodLevel());
        try {
            ProtocolLibrary.getProtocolManager().sendServerPacket(player, packet);
        } catch (InvocationTargetException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onRemove(Player player) {
        updateHunger(player,true);
    }

    @Override
    public void applyCurse(Player player) {
        super.applyCurse(player);
        updateHunger(player, false);
    }
    

}
