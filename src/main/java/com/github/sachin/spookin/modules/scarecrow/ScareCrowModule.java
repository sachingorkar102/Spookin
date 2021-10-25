package com.github.sachin.spookin.modules.scarecrow;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;

import com.destroystokyo.paper.block.TargetBlockInfo.FluidMode;
import com.github.sachin.spookin.BaseItem;
import com.github.sachin.spookin.BaseModule;
import com.github.sachin.spookin.manager.Module;
import com.github.sachin.spookin.utils.Advancements;
import com.github.sachin.spookin.utils.ItemBuilder;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.attribute.Attribute;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.entity.MagmaCube;
import org.bukkit.entity.Player;
import org.bukkit.entity.Slime;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.entity.EntitySpawnEvent;
import org.bukkit.event.player.PlayerInteractAtEntityEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.inventory.meta.LeatherArmorMeta;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.util.EulerAngle;

@Module(name = "scarecrow")
public class ScareCrowModule extends BaseItem implements Listener{

    private final List<EntityType> fleeableEntities = Arrays.asList(EntityType.ZOMBIE,EntityType.HUSK,EntityType.DROWNED,EntityType.SKELETON,EntityType.STRAY,EntityType.WITHER_SKELETON,EntityType.ZOMBIFIED_PIGLIN);
    
    @EventHandler
    public void onPlace(PlayerInteractEvent e){
        if(e.getItem() != null && isSimilar(e.getItem()) && e.getAction()==Action.RIGHT_CLICK_BLOCK){
            e.setCancelled(true);

            if(e.getBlockFace() == BlockFace.UP){
                Player player = e.getPlayer();
                Location spawnLoc = e.getClickedBlock().getLocation().add( 0.5, 1, 0.5);
                spawnLoc.setYaw(player.getEyeLocation().getYaw()+180);
                ArmorStand as = player.getWorld().spawn(spawnLoc, ArmorStand.class);
                Slime cube = player.getWorld().spawn(spawnLoc, Slime.class);
                cube.setAI(false);
                cube.setInvulnerable(true);
                cube.setInvisible(true);
                cube.setSize(1);
                cube.getPersistentDataContainer().set(SConstants.SCARECROW_KEY, PersistentDataType.STRING, "");
                poseScareCrow(as,cube.getUniqueId());
                e.getItem().setAmount(e.getItem().getAmount()-1);
                Advancements.awardAdvancement("scarecrow", player);
                
            }
        }
    }

    @EventHandler
    public void onDeath(EntityDeathEvent e){
        if(e.getEntity() instanceof ArmorStand && e.getEntity().getPersistentDataContainer().has(SConstants.SCARECROW_KEY, PersistentDataType.STRING)){
            ArmorStand as = (ArmorStand) e.getEntity();
            Entity entity = Bukkit.getEntity(UUID.fromString(as.getPersistentDataContainer().get(SConstants.SCARECROW_KEY, PersistentDataType.STRING)));
            if(entity != null && !entity.isDead()){
                entity.remove();
            }
        }
    }

    @EventHandler
    public void onEntitySpawn(EntitySpawnEvent e){
        if(fleeableEntities.contains(e.getEntity().getType())){
            plugin.getNmsHelper().addFleeGoal(e.getEntity());
        }
    }
    

    public void poseScareCrow(ArmorStand as,UUID uuid){
        as.setInvulnerable(true);
        as.setBasePlate(false);
        as.setGravity(false);
        as.getEquipment().setHelmet(getItem());
        ItemStack chest = new ItemStack(Material.LEATHER_CHESTPLATE);
        ItemMeta meta = chest.getItemMeta();
        LeatherArmorMeta leatherArmorMeta = (LeatherArmorMeta) meta;
        leatherArmorMeta.setColor(ItemBuilder.parseColor("RED"));
        chest.setItemMeta(meta);
        as.getEquipment().setChestplate(chest);
        as.getEquipment().setItemInMainHand(new ItemStack(Material.WOODEN_SWORD));
        EulerAngle larm,rarm,lleg,rleg;
        larm = new EulerAngle(0, 0, -1.5);
        rarm = new EulerAngle(0, 1.5, 1.5);
        lleg = new EulerAngle(-0.01, 0, 0.1);
        rleg = new EulerAngle(-0.01, 0, -0.1);
        as.setLeftArmPose(larm); as.setRightArmPose(rarm);
        as.setLeftLegPose(lleg); as.setRightLegPose(rleg);
        as.getPersistentDataContainer().set(SConstants.SCARECROW_KEY, PersistentDataType.STRING, uuid.toString());
    }




    @EventHandler
    public void onInteract(PlayerInteractAtEntityEvent e){
        
        if(e.getRightClicked() instanceof ArmorStand && e.getRightClicked().getPersistentDataContainer().has(SConstants.SCARECROW_KEY, PersistentDataType.STRING)){
            ArmorStand as = (ArmorStand) e.getRightClicked();
            Player player = e.getPlayer();
            e.setCancelled(true);
            if(player.getInventory().getItem(e.getHand()).getType().isAir() && player.isSneaking()){
                try {
                    Entity entity = Bukkit.getEntity(UUID.fromString(as.getPersistentDataContainer().get(SConstants.SCARECROW_KEY, PersistentDataType.STRING)));
                    if(entity != null && !entity.isDead()){
                        entity.remove();
                    }
                } catch (Exception ex) {
                }
                as.remove();
                player.getWorld().dropItem(as.getLocation(), getItem());
            }    
        }
    }
}
