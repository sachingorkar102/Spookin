package com.github.sachin.spookin.modules.curses;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import com.github.sachin.spookin.BaseModule;
import com.github.sachin.spookin.manager.Module;
import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.Advancements;
import com.github.sachin.spookin.utils.Items;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.GameMode;
import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.advancement.Advancement;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.block.data.Levelled;
import org.bukkit.enchantments.Enchantment;
import org.bukkit.entity.Entity;
import org.bukkit.entity.Item;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.PlayerDeathEvent;
import org.bukkit.event.entity.EntityDamageEvent.DamageCause;
import org.bukkit.event.player.PlayerAdvancementDoneEvent;
import org.bukkit.event.player.PlayerDropItemEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.player.PlayerItemConsumeEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.ShapedRecipe;
import org.bukkit.inventory.meta.EnchantmentStorageMeta;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.scheduler.BukkitRunnable;

@Module(name = "curses")
public class CurseModule extends BaseModule implements Listener{

    public final List<BaseCurse> registeredCurses = new ArrayList<>();




    public CurseModule(){
        super();
        ShapedRecipe daggerRecipe = new ShapedRecipe(SConstants.DAGGER_RECIPE, plugin.getItemFolder().DAGGER);
        daggerRecipe.shape("   "," I "," S ");
        daggerRecipe.setIngredient('I', Material.IRON_INGOT);
        daggerRecipe.setIngredient('S', Material.STICK);
        Bukkit.addRecipe(daggerRecipe);
        registeredCurses.add(new LostTongueCurse(this));
        if(plugin.isProtocolLibEnabled){
            registeredCurses.add(new StarvationCurse(this));
            registeredCurses.add(new SicknessCurse(this));
            registeredCurses.add(new FakeFearCurse(this));
        }
        registeredCurses.add(new SlipperyHandsCurse(this));
        registeredCurses.add(new SleepCurse(this));
        registeredCurses.add(new AnimalFearCurse(this));

    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e){
        Advancements.awardAdvancement("root", e.getPlayer());
        for(NamespacedKey key : Arrays.asList(SConstants.LAUNCHER_RECIPE,SConstants.BASKET_RECIPE,SConstants.DAGGER_RECIPE)){
            if(e.getPlayer().hasDiscoveredRecipe(key)){
                e.getPlayer().discoverRecipe(key);
            }
        }
    }

    @EventHandler
    public void onInteract(PlayerInteractEvent e){
        if(Items.hasKey(e.getItem(), "dagger") && (e.getAction()==Action.RIGHT_CLICK_AIR || e.getAction()==Action.RIGHT_CLICK_BLOCK)){
            e.setCancelled(true);
            Player player = e.getPlayer();
            player.damage(1);
            Advancements.awardAdvancement("ithurts",player);
            player.getInventory().setItem(e.getHand(), setImbuedBlood(player));
        }
    }

    @EventHandler
    public void onDamage(EntityDamageByEntityEvent e){
        if(e.getEntity() instanceof Player && e.getDamager() instanceof Player && e.getCause()==DamageCause.ENTITY_ATTACK){
            Player damager = (Player) e.getDamager();
            Player player = (Player) e.getEntity();
            ItemStack weapon = damager.getInventory().getItemInMainHand();
            if(Items.hasKey(weapon, "dagger") && player.getGameMode()==GameMode.SURVIVAL){
                player.damage(1);
                damager.getInventory().setItemInMainHand(setImbuedBlood(player));
            }
        }
    }

    @EventHandler
    public void onDrinkMilk(PlayerItemConsumeEvent e){
        if(e.getItem().getType()==Material.MILK_BUCKET){
            Player player = e.getPlayer();
            removeCurses(player);
        }
    }

    @EventHandler
    public void onDeath(PlayerDeathEvent e){
        removeCurses(e.getEntity());
    }

    public void removeCurses(Player player){
        boolean hadcurse = false;
        for(BaseCurse c : registeredCurses){
            if(player.getPersistentDataContainer().has(c.curseKey, PersistentDataType.STRING)){
                player.getPersistentDataContainer().remove(c.curseKey);
                hadcurse = true;
                c.onRemove(player);
            }
        }
        if(hadcurse){
            player.getWorld().playSound(player.getLocation(),Sound.ENTITY_ZOMBIE_VILLAGER_CONVERTED, 2F,  plugin.RANDOM.nextFloat() * 0.4F + 0.8F);
        }
    }


    @EventHandler
    public void onIngredientDrop(PlayerDropItemEvent e){
        new BukkitRunnable(){
            @Override
            public void run() {
                Item itemEn = e.getItemDrop();
                if(itemEn.isDead()) return;
                Block block = itemEn.getLocation().getBlock();
                if(block.getType()==Material.SOUL_CAMPFIRE){
                    NBTItem nbti = new NBTItem(itemEn.getItemStack());
                    if(nbti.hasKey("binded-player")){
                        String curseName = nbti.getString("curse-book");
                        for(BaseCurse c : registeredCurses){
                            if(c.name.equals(curseName)){
                                Player target = c.getPlayer(itemEn.getItemStack());
                                if(target != null){
                                    c.applyCurse(target);
                                    itemEn.remove();
                                    itemEn.getWorld().spawnParticle(Particle.SPELL, block.getLocation().add(0.5, 0.5, 0.5), 20, 0.2, 0.2, 0.2);
                                    itemEn.getWorld().playSound(itemEn.getLocation(), Sound.ENTITY_ZOMBIE_VILLAGER_CURE, 2F, plugin.RANDOM.nextFloat() * 0.4F + 0.8F);
                                    e.getPlayer().sendMessage(ChatColor.translateAlternateColorCodes('&', "&a"+target.getName()+" &rhas been cursed with &e "+c.name));
                                }
                            }
                        }
                    }
                }
                else if(block.getType()==Material.WATER_CAULDRON){
                    itemEn.teleport(block.getLocation().add(0.5, 0.7, 0.5));
                    Levelled levelled = (Levelled) block.getBlockData();
                    if(levelled.getLevel() > 0){
                        List<Item> ingredients = new ArrayList<>();
                        List<Material> mats = new ArrayList<>();
                        ingredients.add(itemEn);
                        mats.add(itemEn.getItemStack().getType());
                        itemEn.getNearbyEntities(0.5, 0.5, 0.5).forEach(en -> {
                            if(en instanceof Item){
                                ingredients.add((Item)en);
                                mats.add(((Item)en).getItemStack().getType());
                            }
                        });
                        if(!ingredients.isEmpty()){
                            Item book = null;
                            Item dagger = null;
                            BaseCurse curse = null;
                            for(Item i : ingredients){
                                ItemStack item = i.getItemStack();
                                if(isCurseBook(item)){
                                    book = i;
                                }
                                if(Items.hasKey(item, "imbued-dagger")){
                                    dagger = i;
                                }
                                
                            }
                            if(dagger != null && book != null){
                                
                                for(BaseCurse c : registeredCurses){
                                    if(mats.containsAll(c.ingredients)){
                                        curse = c;
                                    }
                                }
                                if(curse != null){
                                    Player targetPlayer = getImbuedPlayer(dagger.getItemStack());
                                    if(targetPlayer != null){
                                        Advancements.awardAdvancement("youawitch",e.getPlayer());
                                        itemEn.getWorld().dropItem(block.getLocation().add(0.5, 0.6, 0.5), curse.bindBook(targetPlayer));
                                        itemEn.getWorld().playSound(itemEn.getLocation(), Sound.BLOCK_ENCHANTMENT_TABLE_USE, 2F, plugin.RANDOM.nextFloat() * 0.4F + 0.8F);
                                        itemEn.getWorld().spawnParticle(Particle.SPELL, block.getLocation().add(0.5, 0.4, 0.5), 50, 0.3, 0.4, 0.2);
                                        if(levelled.getLevel()==1){
                                            block.setType(Material.CAULDRON);
                                        }
                                        else{
                                            levelled.setLevel(levelled.getLevel()-1);
                                            block.setBlockData(levelled);
                                        }
                                        
                                        for(Item i : ingredients){
                                            ItemStack item = i.getItemStack();
                                            if(curse.ingredients.contains(item.getType())){
                                                item.setAmount(item.getAmount()-1);
                                            }
                                            
                                        }
                                        dagger.remove();
                                        book.remove();
                                    }
                                }
                            }
                        }

                    }
                }
            }
        }.runTaskLater(plugin,20);
    }

    public boolean isCurseBook(ItemStack item){
        if(item.getType()==Material.ENCHANTED_BOOK){
            EnchantmentStorageMeta meta = (EnchantmentStorageMeta) item.getItemMeta();
            return meta.getStoredEnchantLevel(Enchantment.BINDING_CURSE) != 0 || meta.getStoredEnchantLevel(Enchantment.VANISHING_CURSE) != 0;
        }
        return false;
    }

    public ItemStack setImbuedBlood(Player player){
            ItemStack imbuedDagger = plugin.getItemFolder().IMBUED_DAGGER.clone();
            ItemMeta meta = imbuedDagger.getItemMeta();
            List<String> lore = new ArrayList<>();
            for(String l : meta.getLore()){
                lore.add(l.replace("%player%", player.getName()));
            }
            meta.setLore(lore);
            imbuedDagger.setItemMeta(meta);
            NBTItem nbtItem = new NBTItem(imbuedDagger);
            nbtItem.setString("imbued-blood", player.getUniqueId().toString());
            return nbtItem.getItem();
    }


    public Player getImbuedPlayer(ItemStack item){
        NBTItem nbti = new NBTItem(item);
        if(nbti.hasKey("imbued-blood")){
            Player player = Bukkit.getPlayer(UUID.fromString(nbti.getString("imbued-blood")));
            if(player != null && player.isOnline()){
                return player;
            }
            
        }
        
        return null;
    }



}
