package net.minecraft.world.entity;

import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;
import com.google.common.collect.Sets;
import com.google.common.collect.UnmodifiableIterator;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Random;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Predicate;
import java.util.stream.Stream;
import javax.annotation.Nullable;
import net.minecraft.BlockUtil;
import net.minecraft.CrashReport;
import net.minecraft.CrashReportSystemDetails;
import net.minecraft.ReportedException;
import net.minecraft.SystemUtils;
import net.minecraft.advancements.CriterionTriggers;
import net.minecraft.commands.CommandListenerWrapper;
import net.minecraft.commands.ICommandListener;
import net.minecraft.commands.arguments.ArgumentAnchor;
import net.minecraft.core.BaseBlockPosition;
import net.minecraft.core.BlockPosition;
import net.minecraft.core.EnumDirection;
import net.minecraft.core.particles.ParticleParam;
import net.minecraft.core.particles.ParticleParamBlock;
import net.minecraft.core.particles.Particles;
import net.minecraft.nbt.NBTBase;
import net.minecraft.nbt.NBTTagCompound;
import net.minecraft.nbt.NBTTagDouble;
import net.minecraft.nbt.NBTTagFloat;
import net.minecraft.nbt.NBTTagList;
import net.minecraft.nbt.NBTTagString;
import net.minecraft.network.chat.ChatHoverable;
import net.minecraft.network.chat.ChatModifier;
import net.minecraft.network.chat.IChatBaseComponent;
import net.minecraft.network.chat.IChatMutableComponent;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.PacketPlayOutSpawnEntity;
import net.minecraft.network.syncher.DataWatcher;
import net.minecraft.network.syncher.DataWatcherObject;
import net.minecraft.network.syncher.DataWatcherRegistry;
import net.minecraft.resources.MinecraftKey;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.EntityPlayer;
import net.minecraft.server.level.TicketType;
import net.minecraft.server.level.WorldServer;
import net.minecraft.sounds.SoundCategory;
import net.minecraft.sounds.SoundEffect;
import net.minecraft.sounds.SoundEffects;
import net.minecraft.tags.Tag;
import net.minecraft.tags.TagsBlock;
import net.minecraft.tags.TagsEntity;
import net.minecraft.tags.TagsFluid;
import net.minecraft.util.MathHelper;
import net.minecraft.util.StreamAccumulator;
import net.minecraft.world.EnumHand;
import net.minecraft.world.EnumInteractionResult;
import net.minecraft.world.INamableTileEntity;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.item.EntityItem;
import net.minecraft.world.entity.player.EntityHuman;
import net.minecraft.world.entity.vehicle.EntityBoat;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.enchantment.EnchantmentManager;
import net.minecraft.world.item.enchantment.EnchantmentProtection;
import net.minecraft.world.level.ChunkCoordIntPair;
import net.minecraft.world.level.Explosion;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.level.IBlockAccess;
import net.minecraft.world.level.IMaterial;
import net.minecraft.world.level.IWorldReader;
import net.minecraft.world.level.LevelHeightAccessor;
import net.minecraft.world.level.RayTrace;
import net.minecraft.world.level.World;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.BlockHoney;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.EnumBlockMirror;
import net.minecraft.world.level.block.EnumBlockRotation;
import net.minecraft.world.level.block.EnumRenderType;
import net.minecraft.world.level.block.SoundEffectType;
import net.minecraft.world.level.block.state.IBlockData;
import net.minecraft.world.level.block.state.properties.BlockProperties;
import net.minecraft.world.level.block.state.properties.IBlockState;
import net.minecraft.world.level.border.WorldBorder;
import net.minecraft.world.level.dimension.DimensionManager;
import net.minecraft.world.level.entity.EntityAccess;
import net.minecraft.world.level.entity.EntityInLevelCallback;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.gameevent.GameEventListenerRegistrar;
import net.minecraft.world.level.levelgen.HeightMap;
import net.minecraft.world.level.material.EnumPistonReaction;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidType;
import net.minecraft.world.level.portal.BlockPortalShape;
import net.minecraft.world.level.portal.ShapeDetectorShape;
import net.minecraft.world.phys.AxisAlignedBB;
import net.minecraft.world.phys.MovingObjectPosition;
import net.minecraft.world.phys.Vec2F;
import net.minecraft.world.phys.Vec3D;
import net.minecraft.world.phys.shapes.OperatorBoolean;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.minecraft.world.phys.shapes.VoxelShapeCollision;
import net.minecraft.world.phys.shapes.VoxelShapes;
import net.minecraft.world.scores.ScoreboardTeam;
import net.minecraft.world.scores.ScoreboardTeamBase;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.Server;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.command.CommandSender;
import org.bukkit.craftbukkit.libs.it.unimi.dsi.fastutil.objects.Object2DoubleArrayMap;
import org.bukkit.craftbukkit.libs.it.unimi.dsi.fastutil.objects.Object2DoubleMap;
import org.bukkit.craftbukkit.v1_17_R1.CraftServer;
import org.bukkit.craftbukkit.v1_17_R1.CraftWorld;
import org.bukkit.craftbukkit.v1_17_R1.SpigotTimings;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftEntity;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftPlayer;
import org.bukkit.craftbukkit.v1_17_R1.event.CraftEventFactory;
import org.bukkit.craftbukkit.v1_17_R1.event.CraftPortalEvent;
import org.bukkit.craftbukkit.v1_17_R1.inventory.CraftItemStack;
import org.bukkit.entity.Hanging;
import org.bukkit.entity.Item;
import org.bukkit.entity.LivingEntity;
import org.bukkit.entity.Pose;
import org.bukkit.entity.Vehicle;
import org.bukkit.event.Event;
import org.bukkit.event.entity.EntityAirChangeEvent;
import org.bukkit.event.entity.EntityCombustByBlockEvent;
import org.bukkit.event.entity.EntityCombustByEntityEvent;
import org.bukkit.event.entity.EntityCombustEvent;
import org.bukkit.event.entity.EntityDropItemEvent;
import org.bukkit.event.entity.EntityPortalEvent;
import org.bukkit.event.entity.EntityPoseChangeEvent;
import org.bukkit.event.hanging.HangingBreakByEntityEvent;
import org.bukkit.event.player.PlayerTeleportEvent;
import org.bukkit.event.vehicle.VehicleBlockCollisionEvent;
import org.bukkit.event.vehicle.VehicleEnterEvent;
import org.bukkit.event.vehicle.VehicleExitEvent;
import org.bukkit.plugin.PluginManager;
import org.bukkit.projectiles.ProjectileSource;
import org.spigotmc.ActivationRange;
import org.spigotmc.CustomTimingsHandler;
import org.spigotmc.event.entity.EntityDismountEvent;
import org.spigotmc.event.entity.EntityMountEvent;

public abstract class Entity implements INamableTileEntity, EntityAccess, ICommandListener {
  private static final int CURRENT_LEVEL = 2;
  
  private CraftEntity bukkitEntity;
  
  static boolean isLevelAtLeast(NBTTagCompound tag, int level) {
    return (tag.hasKey("Bukkit.updateLevel") && tag.getInt("Bukkit.updateLevel") >= level);
  }
  
  public CraftEntity getBukkitEntity() {
    if (this.bukkitEntity == null)
      this.bukkitEntity = CraftEntity.getEntity(this.t.getCraftServer(), this); 
    return this.bukkitEntity;
  }
  
  public CommandSender getBukkitSender(CommandListenerWrapper wrapper) {
    return (CommandSender)getBukkitEntity();
  }
  
  protected static final Logger g = LogManager.getLogger();
  
  public static final String h = "id";
  
  public static final String i = "Passengers";
  
  private static final AtomicInteger b = new AtomicInteger();
  
  private static final List<ItemStack> c = Collections.emptyList();
  
  public static final int j = 60;
  
  public static final int k = 300;
  
  public static final int l = 1024;
  
  public static final double m = 0.5000001D;
  
  public static final float n = 0.11111111F;
  
  public static final int o = 140;
  
  public static final int p = 40;
  
  private static final AxisAlignedBB d = new AxisAlignedBB(0.0D, 0.0D, 0.0D, 0.0D, 0.0D, 0.0D);
  
  private static final double e = 0.014D;
  
  private static final double ao = 0.007D;
  
  private static final double ap = 0.0023333333333333335D;
  
  public static final String q = "UUID";
  
  private static double aq = 1.0D;
  
  private final EntityTypes<?> ar;
  
  private int as;
  
  public boolean r;
  
  public ImmutableList<Entity> at;
  
  protected int s;
  
  @Nullable
  private Entity au;
  
  public World t;
  
  public double u;
  
  public double v;
  
  public double w;
  
  private Vec3D av;
  
  private BlockPosition aw;
  
  private Vec3D ax;
  
  private float ay;
  
  private float az;
  
  public float x;
  
  public float y;
  
  private AxisAlignedBB aA;
  
  protected boolean z;
  
  public boolean A;
  
  public boolean B;
  
  public boolean C;
  
  protected Vec3D D;
  
  @Nullable
  private RemovalReason aB;
  
  public static final float E = 0.6F;
  
  public static final float F = 1.8F;
  
  public float G;
  
  public float H;
  
  public float I;
  
  public float J;
  
  public float K;
  
  private float aC;
  
  public double L;
  
  public double M;
  
  public double N;
  
  public float O;
  
  public boolean P;
  
  protected final Random Q;
  
  public int R;
  
  public int aD;
  
  public boolean S;
  
  protected Object2DoubleMap<Tag<FluidType>> T;
  
  protected boolean U;
  
  @Nullable
  protected Tag<FluidType> V;
  
  public int W;
  
  protected boolean X;
  
  protected final DataWatcher Y;
  
  protected static final DataWatcherObject<Byte> Z = DataWatcher.a(Entity.class, DataWatcherRegistry.a);
  
  protected static final int aa = 0;
  
  private static final int aE = 1;
  
  private static final int aF = 3;
  
  private static final int aG = 4;
  
  private static final int aH = 5;
  
  protected static final int ab = 6;
  
  protected static final int ac = 7;
  
  private static final DataWatcherObject<Integer> aI = DataWatcher.a(Entity.class, DataWatcherRegistry.b);
  
  private static final DataWatcherObject<Optional<IChatBaseComponent>> aJ = DataWatcher.a(Entity.class, DataWatcherRegistry.f);
  
  private static final DataWatcherObject<Boolean> aK = DataWatcher.a(Entity.class, DataWatcherRegistry.i);
  
  private static final DataWatcherObject<Boolean> aL = DataWatcher.a(Entity.class, DataWatcherRegistry.i);
  
  private static final DataWatcherObject<Boolean> aM = DataWatcher.a(Entity.class, DataWatcherRegistry.i);
  
  protected static final DataWatcherObject<EntityPose> ad = DataWatcher.a(Entity.class, DataWatcherRegistry.s);
  
  private static final DataWatcherObject<Integer> aN = DataWatcher.a(Entity.class, DataWatcherRegistry.b);
  
  private EntityInLevelCallback aO;
  
  private Vec3D aP;
  
  public boolean ae;
  
  public boolean af;
  
  public int aQ;
  
  protected boolean ag;
  
  protected int ah;
  
  protected BlockPosition ai;
  
  private boolean aR;
  
  protected UUID aj;
  
  protected String ak;
  
  private boolean aS;
  
  private final Set<String> aT;
  
  private final double[] aU;
  
  private long aV;
  
  private EntitySize aW;
  
  private float aX;
  
  public boolean al;
  
  public boolean am;
  
  public boolean an;
  
  private float aY;
  
  private int aZ;
  
  public boolean ba;
  
  public boolean persist = true;
  
  public boolean valid;
  
  public boolean generation;
  
  public ProjectileSource projectileSource;
  
  public boolean forceExplosionKnockback;
  
  public boolean persistentInvisibility = false;
  
  public CustomTimingsHandler tickTimer = SpigotTimings.getEntityTimings(this);
  
  public final ActivationRange.ActivationType activationType = ActivationRange.initializeEntityActivationType(this);
  
  public final boolean defaultActivationState;
  
  public long activatedTick = -2147483648L;
  
  public void inactiveTick() {}
  
  public float getBukkitYaw() {
    return this.ay;
  }
  
  public boolean isChunkLoaded() {
    return this.t.isChunkLoaded((int)Math.floor(locX()) >> 4, (int)Math.floor(locZ()) >> 4);
  }
  
  public Entity(EntityTypes<?> entitytypes, World world) {
    this.as = b.incrementAndGet();
    this.at = ImmutableList.of();
    this.ax = Vec3D.a;
    this.aA = d;
    this.D = Vec3D.a;
    this.aC = 1.0F;
    this.Q = new Random();
    this.aD = -getMaxFireTicks();
    this.T = (Object2DoubleMap<Tag<FluidType>>)new Object2DoubleArrayMap(2);
    this.X = true;
    this.aO = EntityInLevelCallback.a;
    this.aj = MathHelper.a(this.Q);
    this.ak = this.aj.toString();
    this.aT = Sets.newHashSet();
    this.aU = new double[] { 0.0D, 0.0D, 0.0D };
    this.ar = entitytypes;
    this.t = world;
    this.aW = entitytypes.m();
    this.av = Vec3D.a;
    this.aw = BlockPosition.b;
    this.aP = Vec3D.a;
    if (world != null) {
      this.defaultActivationState = ActivationRange.initializeEntityActivationState(this, world.spigotConfig);
    } else {
      this.defaultActivationState = false;
    } 
    this.Y = new DataWatcher(this);
    this.Y.register(Z, Byte.valueOf((byte)0));
    this.Y.register(aI, Integer.valueOf(bS()));
    this.Y.register(aK, Boolean.valueOf(false));
    this.Y.register(aJ, Optional.empty());
    this.Y.register(aL, Boolean.valueOf(false));
    this.Y.register(aM, Boolean.valueOf(false));
    this.Y.register(ad, EntityPose.a);
    this.Y.register(aN, Integer.valueOf(0));
    initDatawatcher();
    (getDataWatcher()).registrationLocked = true;
    setPosition(0.0D, 0.0D, 0.0D);
    this.aX = getHeadHeight(EntityPose.a, this.aW);
  }
  
  public boolean a(BlockPosition blockposition, IBlockData iblockdata) {
    VoxelShape voxelshape = iblockdata.b((IBlockAccess)this.t, blockposition, VoxelShapeCollision.a(this));
    VoxelShape voxelshape1 = voxelshape.a(blockposition.getX(), blockposition.getY(), blockposition.getZ());
    return VoxelShapes.c(voxelshape1, VoxelShapes.a(getBoundingBox()), OperatorBoolean.i);
  }
  
  public int V() {
    ScoreboardTeamBase scoreboardteambase = getScoreboardTeam();
    return (scoreboardteambase != null && scoreboardteambase.getColor().e() != null) ? scoreboardteambase.getColor().e().intValue() : 16777215;
  }
  
  public boolean isSpectator() {
    return false;
  }
  
  public final void decouple() {
    if (isVehicle())
      ejectPassengers(); 
    if (isPassenger())
      stopRiding(); 
  }
  
  public void d(double d0, double d1, double d2) {
    a_(new Vec3D(d0, d1, d2));
  }
  
  public void a_(Vec3D vec3d) {
    this.aP = vec3d;
  }
  
  public Vec3D X() {
    return this.aP;
  }
  
  public EntityTypes<?> getEntityType() {
    return this.ar;
  }
  
  public int getId() {
    return this.as;
  }
  
  public void e(int i) {
    this.as = i;
  }
  
  public Set<String> getScoreboardTags() {
    return this.aT;
  }
  
  public boolean addScoreboardTag(String s) {
    return (this.aT.size() >= 1024) ? false : this.aT.add(s);
  }
  
  public boolean removeScoreboardTag(String s) {
    return this.aT.remove(s);
  }
  
  public void killEntity() {
    a(RemovalReason.a);
  }
  
  public final void die() {
    a(RemovalReason.b);
  }
  
  public DataWatcher getDataWatcher() {
    return this.Y;
  }
  
  public boolean equals(Object object) {
    return (object instanceof Entity) ? ((((Entity)object).as == this.as)) : false;
  }
  
  public int hashCode() {
    return this.as;
  }
  
  public void a(RemovalReason entity_removalreason) {
    setRemoved(entity_removalreason);
    if (entity_removalreason == RemovalReason.a)
      a(GameEvent.s); 
  }
  
  public void ae() {}
  
  public void setPose(EntityPose entitypose) {
    if (entitypose == getPose())
      return; 
    this.t.getCraftServer().getPluginManager().callEvent((Event)new EntityPoseChangeEvent((org.bukkit.entity.Entity)getBukkitEntity(), Pose.values()[entitypose.ordinal()]));
    this.Y.set(ad, entitypose);
  }
  
  public EntityPose getPose() {
    return (EntityPose)this.Y.get(ad);
  }
  
  public boolean a(Entity entity, double d0) {
    double d1 = entity.av.b - this.av.b;
    double d2 = entity.av.c - this.av.c;
    double d3 = entity.av.d - this.av.d;
    return (d1 * d1 + d2 * d2 + d3 * d3 < d0 * d0);
  }
  
  protected void setYawPitch(float f, float f1) {
    if (Float.isNaN(f))
      f = 0.0F; 
    if (f == Float.POSITIVE_INFINITY || f == Float.NEGATIVE_INFINITY) {
      if (this instanceof EntityPlayer) {
        this.t.getCraftServer().getLogger().warning(String.valueOf(getName()) + " was caught trying to crash the server with an invalid yaw");
        ((CraftPlayer)getBukkitEntity()).kickPlayer("Infinite yaw (Hacking?)");
      } 
      f = 0.0F;
    } 
    if (Float.isNaN(f1))
      f1 = 0.0F; 
    if (f1 == Float.POSITIVE_INFINITY || f1 == Float.NEGATIVE_INFINITY) {
      if (this instanceof EntityPlayer) {
        this.t.getCraftServer().getLogger().warning(String.valueOf(getName()) + " was caught trying to crash the server with an invalid pitch");
        ((CraftPlayer)getBukkitEntity()).kickPlayer("Infinite pitch (Hacking?)");
      } 
      f1 = 0.0F;
    } 
    setYRot(f % 360.0F);
    setXRot(f1 % 360.0F);
  }
  
  public final void b(Vec3D vec3d) {
    setPosition(vec3d.getX(), vec3d.getY(), vec3d.getZ());
  }
  
  public void setPosition(double d0, double d1, double d2) {
    setPositionRaw(d0, d1, d2);
    a(ag());
  }
  
  protected AxisAlignedBB ag() {
    return this.aW.a(this.av);
  }
  
  protected void ah() {
    setPosition(this.av.b, this.av.c, this.av.d);
  }
  
  public void a(double d0, double d1) {
    float f = (float)d1 * 0.15F;
    float f1 = (float)d0 * 0.15F;
    setXRot(getXRot() + f);
    setYRot(getYRot() + f1);
    setXRot(MathHelper.a(getXRot(), -90.0F, 90.0F));
    this.y += f;
    this.x += f1;
    this.y = MathHelper.a(this.y, -90.0F, 90.0F);
    if (this.au != null)
      this.au.j(this); 
  }
  
  public void tick() {
    entityBaseTick();
  }
  
  public void postTick() {
    if (!(this instanceof EntityPlayer))
      doPortalTick(); 
  }
  
  public void entityBaseTick() {
    this.t.getMethodProfiler().enter("entityBaseTick");
    if (isPassenger() && getVehicle().isRemoved())
      stopRiding(); 
    if (this.s > 0)
      this.s--; 
    this.G = this.H;
    this.y = getXRot();
    this.x = getYRot();
    if (this instanceof EntityPlayer)
      doPortalTick(); 
    if (aV())
      aW(); 
    this.am = this.al;
    this.al = false;
    aR();
    l();
    aQ();
    if (this.t.y) {
      extinguish();
    } else if (this.aD > 0) {
      if (isFireProof()) {
        setFireTicks(this.aD - 4);
        if (this.aD < 0)
          extinguish(); 
      } else {
        if (this.aD % 20 == 0 && !aX())
          damageEntity(DamageSource.c, 1.0F); 
        setFireTicks(this.aD - 1);
      } 
      if (getTicksFrozen() > 0) {
        setTicksFrozen(0);
        this.t.a(null, 1009, this.aw, 1);
      } 
    } 
    if (aX()) {
      burnFromLava();
      this.K *= 0.5F;
    } 
    aj();
    if (!this.t.y)
      a_((this.aD > 0)); 
    this.X = false;
    this.t.getMethodProfiler().exit();
  }
  
  public void a_(boolean flag) {
    setFlag(0, !(!flag && !this.ba));
  }
  
  public void aj() {
    if (locY() < (this.t.getMinBuildHeight() - 64))
      aq(); 
  }
  
  public void resetPortalCooldown() {
    this.aQ = getDefaultPortalCooldown();
  }
  
  public boolean al() {
    return (this.aQ > 0);
  }
  
  protected void E() {
    if (al())
      this.aQ--; 
  }
  
  public int am() {
    return 0;
  }
  
  public void burnFromLava() {
    if (!isFireProof()) {
      if (this instanceof EntityLiving && this.aD <= 0) {
        Block damager = null;
        CraftEntity craftEntity = getBukkitEntity();
        EntityCombustByBlockEvent entityCombustByBlockEvent = new EntityCombustByBlockEvent(damager, (org.bukkit.entity.Entity)craftEntity, 15);
        this.t.getCraftServer().getPluginManager().callEvent((Event)entityCombustByBlockEvent);
        if (!entityCombustByBlockEvent.isCancelled())
          setOnFire(entityCombustByBlockEvent.getDuration(), false); 
      } else {
        setOnFire(15, false);
      } 
      if (damageEntity(DamageSource.d, 4.0F))
        playSound(SoundEffects.gF, 0.4F, 2.0F + this.Q.nextFloat() * 0.4F); 
    } 
  }
  
  public void setOnFire(int i) {
    setOnFire(i, true);
  }
  
  public void setOnFire(int i, boolean callEvent) {
    if (callEvent) {
      EntityCombustEvent event = new EntityCombustEvent((org.bukkit.entity.Entity)getBukkitEntity(), i);
      this.t.getCraftServer().getPluginManager().callEvent((Event)event);
      if (event.isCancelled())
        return; 
      i = event.getDuration();
    } 
    int j = i * 20;
    if (this instanceof EntityLiving)
      j = EnchantmentProtection.a((EntityLiving)this, j); 
    if (this.aD < j)
      setFireTicks(j); 
  }
  
  public void setFireTicks(int i) {
    this.aD = i;
  }
  
  public int getFireTicks() {
    return this.aD;
  }
  
  public void extinguish() {
    setFireTicks(0);
  }
  
  protected void aq() {
    die();
  }
  
  public boolean f(double d0, double d1, double d2) {
    return b(getBoundingBox().d(d0, d1, d2));
  }
  
  private boolean b(AxisAlignedBB axisalignedbb) {
    return (this.t.getCubes(this, axisalignedbb) && !this.t.containsLiquid(axisalignedbb));
  }
  
  public void setOnGround(boolean flag) {
    this.z = flag;
  }
  
  public boolean isOnGround() {
    return this.z;
  }
  
  public void move(EnumMoveType enummovetype, Vec3D vec3d) {
    SpigotTimings.entityMoveTimer.startTiming();
    if (this.P) {
      setPosition(locX() + vec3d.b, locY() + vec3d.c, locZ() + vec3d.d);
    } else {
      this.an = isBurning();
      if (enummovetype == EnumMoveType.c) {
        vec3d = c(vec3d);
        if (vec3d.equals(Vec3D.a))
          return; 
      } 
      this.t.getMethodProfiler().enter("move");
      if (this.D.g() > 1.0E-7D) {
        vec3d = vec3d.h(this.D);
        this.D = Vec3D.a;
        setMot(Vec3D.a);
      } 
      vec3d = a(vec3d, enummovetype);
      Vec3D vec3d1 = g(vec3d);
      if (vec3d1.g() > 1.0E-7D)
        setPosition(locX() + vec3d1.b, locY() + vec3d1.c, locZ() + vec3d1.d); 
      this.t.getMethodProfiler().exit();
      this.t.getMethodProfiler().enter("rest");
      this.A = !(MathHelper.b(vec3d.b, vec3d1.b) && MathHelper.b(vec3d.d, vec3d1.d));
      this.B = (vec3d.c != vec3d1.c);
      this.z = (this.B && vec3d.c < 0.0D);
      BlockPosition blockposition = av();
      IBlockData iblockdata = this.t.getType(blockposition);
      a(vec3d1.c, this.z, iblockdata, blockposition);
      if (isRemoved()) {
        this.t.getMethodProfiler().exit();
      } else {
        Vec3D vec3d2 = getMot();
        if (vec3d.b != vec3d1.b)
          setMot(0.0D, vec3d2.c, vec3d2.d); 
        if (vec3d.d != vec3d1.d)
          setMot(vec3d2.b, vec3d2.c, 0.0D); 
        Block block = iblockdata.getBlock();
        if (vec3d.c != vec3d1.c)
          block.a((IBlockAccess)this.t, this); 
        if (this.A && getBukkitEntity() instanceof Vehicle) {
          Vehicle vehicle = (Vehicle)getBukkitEntity();
          Block bl = this.t.getWorld().getBlockAt(MathHelper.floor(locX()), MathHelper.floor(locY()), MathHelper.floor(locZ()));
          if (vec3d.b > vec3d1.b) {
            bl = bl.getRelative(BlockFace.EAST);
          } else if (vec3d.b < vec3d1.b) {
            bl = bl.getRelative(BlockFace.WEST);
          } else if (vec3d.d > vec3d1.d) {
            bl = bl.getRelative(BlockFace.SOUTH);
          } else if (vec3d.d < vec3d1.d) {
            bl = bl.getRelative(BlockFace.NORTH);
          } 
          if (!bl.getType().isAir()) {
            VehicleBlockCollisionEvent event = new VehicleBlockCollisionEvent(vehicle, bl);
            this.t.getCraftServer().getPluginManager().callEvent((Event)event);
          } 
        } 
        if (this.z && !bE())
          block.stepOn(this.t, blockposition, iblockdata, this); 
        MovementEmission entity_movementemission = aI();
        if (entity_movementemission.a() && !isPassenger()) {
          double d0 = vec3d1.b;
          double d1 = vec3d1.c;
          double d2 = vec3d1.d;
          this.J = (float)(this.J + vec3d1.f() * 0.6D);
          if (!iblockdata.a((Tag)TagsBlock.aC) && !iblockdata.a(Blocks.oO))
            d1 = 0.0D; 
          this.H += (float)vec3d1.h() * 0.6F;
          this.I += (float)Math.sqrt(d0 * d0 + d1 * d1 + d2 * d2) * 0.6F;
          if (this.I > this.aC && !iblockdata.isAir()) {
            this.aC = az();
            if (isInWater()) {
              if (entity_movementemission.c()) {
                Entity entity = (isVehicle() && getRidingPassenger() != null) ? getRidingPassenger() : this;
                float f = (entity == this) ? 0.35F : 0.4F;
                Vec3D vec3d3 = entity.getMot();
                float f1 = Math.min(1.0F, (float)Math.sqrt(vec3d3.b * vec3d3.b * 0.20000000298023224D + vec3d3.c * vec3d3.c + vec3d3.d * vec3d3.d * 0.20000000298023224D) * f);
                d(f1);
              } 
              if (entity_movementemission.b())
                a(GameEvent.R); 
            } else {
              if (entity_movementemission.c()) {
                b(iblockdata);
                b(blockposition, iblockdata);
              } 
              if (entity_movementemission.b() && !iblockdata.a((Tag)TagsBlock.aY))
                a(GameEvent.Q); 
            } 
          } else if (iblockdata.isAir()) {
            au();
          } 
        } 
        as();
        float f2 = getBlockSpeedFactor();
        setMot(getMot().d(f2, 1.0D, f2));
        if (this.t.c(getBoundingBox().shrink(1.0E-6D)).noneMatch(iblockdata1 -> 
            !(!iblockdata1.a((Tag)TagsBlock.aw) && !iblockdata1.a(Blocks.B)))) {
          if (this.aD <= 0)
            setFireTicks(-getMaxFireTicks()); 
          if (this.an && (this.al || aN()))
            at(); 
        } 
        if (isBurning() && (this.al || aN()))
          setFireTicks(-getMaxFireTicks()); 
        this.t.getMethodProfiler().exit();
      } 
    } 
    SpigotTimings.entityMoveTimer.stopTiming();
  }
  
  protected void as() {
    try {
      checkBlockCollisions();
    } catch (Throwable throwable) {
      CrashReport crashreport = CrashReport.a(throwable, "Checking entity block collision");
      CrashReportSystemDetails crashreportsystemdetails = crashreport.a("Entity being checked for collision");
      appendEntityCrashDetails(crashreportsystemdetails);
      throw new ReportedException(crashreport);
    } 
  }
  
  protected void at() {
    playSound(SoundEffects.gK, 0.7F, 1.6F + (this.Q.nextFloat() - this.Q.nextFloat()) * 0.4F);
  }
  
  protected void au() {
    if (aF()) {
      aE();
      if (aI().b())
        a(GameEvent.y); 
    } 
  }
  
  public BlockPosition av() {
    int i = MathHelper.floor(this.av.b);
    int j = MathHelper.floor(this.av.c - 0.20000000298023224D);
    int k = MathHelper.floor(this.av.d);
    BlockPosition blockposition = new BlockPosition(i, j, k);
    if (this.t.getType(blockposition).isAir()) {
      BlockPosition blockposition1 = blockposition.down();
      IBlockData iblockdata = this.t.getType(blockposition1);
      if (iblockdata.a((Tag)TagsBlock.M) || iblockdata.a((Tag)TagsBlock.F) || iblockdata.getBlock() instanceof net.minecraft.world.level.block.BlockFenceGate)
        return blockposition1; 
    } 
    return blockposition;
  }
  
  protected float getBlockJumpFactor() {
    float f = this.t.getType(getChunkCoordinates()).getBlock().getJumpFactor();
    float f1 = this.t.getType(ay()).getBlock().getJumpFactor();
    return (f == 1.0D) ? f1 : f;
  }
  
  protected float getBlockSpeedFactor() {
    IBlockData iblockdata = this.t.getType(getChunkCoordinates());
    float f = iblockdata.getBlock().getSpeedFactor();
    return (!iblockdata.a(Blocks.A) && !iblockdata.a(Blocks.lq)) ? ((f == 1.0D) ? this.t.getType(ay()).getBlock().getSpeedFactor() : f) : f;
  }
  
  protected BlockPosition ay() {
    return new BlockPosition(this.av.b, (getBoundingBox()).b - 0.5000001D, this.av.d);
  }
  
  protected Vec3D a(Vec3D vec3d, EnumMoveType enummovetype) {
    return vec3d;
  }
  
  protected Vec3D c(Vec3D vec3d) {
    if (vec3d.g() <= 1.0E-7D)
      return vec3d; 
    long i = this.t.getTime();
    if (i != this.aV) {
      Arrays.fill(this.aU, 0.0D);
      this.aV = i;
    } 
    if (vec3d.b != 0.0D) {
      double d0 = a(EnumDirection.EnumAxis.a, vec3d.b);
      return (Math.abs(d0) <= 9.999999747378752E-6D) ? Vec3D.a : new Vec3D(d0, 0.0D, 0.0D);
    } 
    if (vec3d.c != 0.0D) {
      double d0 = a(EnumDirection.EnumAxis.b, vec3d.c);
      return (Math.abs(d0) <= 9.999999747378752E-6D) ? Vec3D.a : new Vec3D(0.0D, d0, 0.0D);
    } 
    if (vec3d.d != 0.0D) {
      double d0 = a(EnumDirection.EnumAxis.c, vec3d.d);
      return (Math.abs(d0) <= 9.999999747378752E-6D) ? Vec3D.a : new Vec3D(0.0D, 0.0D, d0);
    } 
    return Vec3D.a;
  }
  
  private double a(EnumDirection.EnumAxis enumdirection_enumaxis, double d0) {
    int i = enumdirection_enumaxis.ordinal();
    double d1 = MathHelper.a(d0 + this.aU[i], -0.51D, 0.51D);
    d0 = d1 - this.aU[i];
    this.aU[i] = d1;
    return d0;
  }
  
  private Vec3D g(Vec3D vec3d) {
    AxisAlignedBB axisalignedbb = getBoundingBox();
    VoxelShapeCollision voxelshapecollision = VoxelShapeCollision.a(this);
    VoxelShape voxelshape = this.t.getWorldBorder().c();
    Stream<VoxelShape> stream = VoxelShapes.c(voxelshape, VoxelShapes.a(axisalignedbb.shrink(1.0E-7D)), OperatorBoolean.i) ? Stream.<VoxelShape>empty() : Stream.<VoxelShape>of(voxelshape);
    Stream<VoxelShape> stream1 = this.t.c(this, axisalignedbb.b(vec3d), entity -> true);
    StreamAccumulator<VoxelShape> streamaccumulator = new StreamAccumulator(Stream.concat(stream1, stream));
    Vec3D vec3d1 = (vec3d.g() == 0.0D) ? vec3d : a(this, vec3d, axisalignedbb, this.t, voxelshapecollision, streamaccumulator);
    boolean flag = (vec3d.b != vec3d1.b);
    boolean flag1 = (vec3d.c != vec3d1.c);
    boolean flag2 = (vec3d.d != vec3d1.d);
    boolean flag3 = !(!this.z && (!flag1 || vec3d.c >= 0.0D));
    if (this.O > 0.0F && flag3 && (flag || flag2)) {
      Vec3D vec3d2 = a(this, new Vec3D(vec3d.b, this.O, vec3d.d), axisalignedbb, this.t, voxelshapecollision, streamaccumulator);
      Vec3D vec3d3 = a(this, new Vec3D(0.0D, this.O, 0.0D), axisalignedbb.b(vec3d.b, 0.0D, vec3d.d), this.t, voxelshapecollision, streamaccumulator);
      if (vec3d3.c < this.O) {
        Vec3D vec3d4 = a(this, new Vec3D(vec3d.b, 0.0D, vec3d.d), axisalignedbb.c(vec3d3), this.t, voxelshapecollision, streamaccumulator).e(vec3d3);
        if (vec3d4.i() > vec3d2.i())
          vec3d2 = vec3d4; 
      } 
      if (vec3d2.i() > vec3d1.i())
        return vec3d2.e(a(this, new Vec3D(0.0D, -vec3d2.c + vec3d.c, 0.0D), axisalignedbb.c(vec3d2), this.t, voxelshapecollision, streamaccumulator)); 
    } 
    return vec3d1;
  }
  
  public static Vec3D a(@Nullable Entity entity, Vec3D vec3d, AxisAlignedBB axisalignedbb, World world, VoxelShapeCollision voxelshapecollision, StreamAccumulator<VoxelShape> streamaccumulator) {
    boolean flag = (vec3d.b == 0.0D);
    boolean flag1 = (vec3d.c == 0.0D);
    boolean flag2 = (vec3d.d == 0.0D);
    if ((!flag || !flag1) && (!flag || !flag2) && (!flag1 || !flag2)) {
      StreamAccumulator<VoxelShape> streamaccumulator1 = new StreamAccumulator(Stream.concat(streamaccumulator.a(), world.b(entity, axisalignedbb.b(vec3d))));
      return a(vec3d, axisalignedbb, streamaccumulator1);
    } 
    return a(vec3d, axisalignedbb, (IWorldReader)world, voxelshapecollision, streamaccumulator);
  }
  
  public static Vec3D a(Vec3D vec3d, AxisAlignedBB axisalignedbb, StreamAccumulator<VoxelShape> streamaccumulator) {
    double d0 = vec3d.b;
    double d1 = vec3d.c;
    double d2 = vec3d.d;
    if (d1 != 0.0D) {
      d1 = VoxelShapes.a(EnumDirection.EnumAxis.b, axisalignedbb, streamaccumulator.a(), d1);
      if (d1 != 0.0D)
        axisalignedbb = axisalignedbb.d(0.0D, d1, 0.0D); 
    } 
    boolean flag = (Math.abs(d0) < Math.abs(d2));
    if (flag && d2 != 0.0D) {
      d2 = VoxelShapes.a(EnumDirection.EnumAxis.c, axisalignedbb, streamaccumulator.a(), d2);
      if (d2 != 0.0D)
        axisalignedbb = axisalignedbb.d(0.0D, 0.0D, d2); 
    } 
    if (d0 != 0.0D) {
      d0 = VoxelShapes.a(EnumDirection.EnumAxis.a, axisalignedbb, streamaccumulator.a(), d0);
      if (!flag && d0 != 0.0D)
        axisalignedbb = axisalignedbb.d(d0, 0.0D, 0.0D); 
    } 
    if (!flag && d2 != 0.0D)
      d2 = VoxelShapes.a(EnumDirection.EnumAxis.c, axisalignedbb, streamaccumulator.a(), d2); 
    return new Vec3D(d0, d1, d2);
  }
  
  public static Vec3D a(Vec3D vec3d, AxisAlignedBB axisalignedbb, IWorldReader iworldreader, VoxelShapeCollision voxelshapecollision, StreamAccumulator<VoxelShape> streamaccumulator) {
    double d0 = vec3d.b;
    double d1 = vec3d.c;
    double d2 = vec3d.d;
    if (d1 != 0.0D) {
      d1 = VoxelShapes.a(EnumDirection.EnumAxis.b, axisalignedbb, iworldreader, d1, voxelshapecollision, streamaccumulator.a());
      if (d1 != 0.0D)
        axisalignedbb = axisalignedbb.d(0.0D, d1, 0.0D); 
    } 
    boolean flag = (Math.abs(d0) < Math.abs(d2));
    if (flag && d2 != 0.0D) {
      d2 = VoxelShapes.a(EnumDirection.EnumAxis.c, axisalignedbb, iworldreader, d2, voxelshapecollision, streamaccumulator.a());
      if (d2 != 0.0D)
        axisalignedbb = axisalignedbb.d(0.0D, 0.0D, d2); 
    } 
    if (d0 != 0.0D) {
      d0 = VoxelShapes.a(EnumDirection.EnumAxis.a, axisalignedbb, iworldreader, d0, voxelshapecollision, streamaccumulator.a());
      if (!flag && d0 != 0.0D)
        axisalignedbb = axisalignedbb.d(d0, 0.0D, 0.0D); 
    } 
    if (!flag && d2 != 0.0D)
      d2 = VoxelShapes.a(EnumDirection.EnumAxis.c, axisalignedbb, iworldreader, d2, voxelshapecollision, streamaccumulator.a()); 
    return new Vec3D(d0, d1, d2);
  }
  
  protected float az() {
    return ((int)this.I + 1);
  }
  
  protected SoundEffect getSoundSwim() {
    return SoundEffects.gO;
  }
  
  protected SoundEffect getSoundSplash() {
    return SoundEffects.gN;
  }
  
  protected SoundEffect getSoundSplashHighSpeed() {
    return SoundEffects.gN;
  }
  
  protected void checkBlockCollisions() {
    AxisAlignedBB axisalignedbb = getBoundingBox();
    BlockPosition blockposition = new BlockPosition(axisalignedbb.a + 0.001D, axisalignedbb.b + 0.001D, axisalignedbb.c + 0.001D);
    BlockPosition blockposition1 = new BlockPosition(axisalignedbb.d - 0.001D, axisalignedbb.e - 0.001D, axisalignedbb.f - 0.001D);
    if (this.t.areChunksLoadedBetween(blockposition, blockposition1)) {
      BlockPosition.MutableBlockPosition blockposition_mutableblockposition = new BlockPosition.MutableBlockPosition();
      for (int i = blockposition.getX(); i <= blockposition1.getX(); i++) {
        for (int j = blockposition.getY(); j <= blockposition1.getY(); j++) {
          for (int k = blockposition.getZ(); k <= blockposition1.getZ(); k++) {
            blockposition_mutableblockposition.d(i, j, k);
            IBlockData iblockdata = this.t.getType((BlockPosition)blockposition_mutableblockposition);
            try {
              iblockdata.a(this.t, (BlockPosition)blockposition_mutableblockposition, this);
              a(iblockdata);
            } catch (Throwable throwable) {
              CrashReport crashreport = CrashReport.a(throwable, "Colliding entity with block");
              CrashReportSystemDetails crashreportsystemdetails = crashreport.a("Block being collided with");
              CrashReportSystemDetails.a(crashreportsystemdetails, (LevelHeightAccessor)this.t, (BlockPosition)blockposition_mutableblockposition, iblockdata);
              throw new ReportedException(crashreport);
            } 
          } 
        } 
      } 
    } 
  }
  
  protected void a(IBlockData iblockdata) {}
  
  public void a(GameEvent gameevent, @Nullable Entity entity, BlockPosition blockposition) {
    this.t.a(entity, gameevent, blockposition);
  }
  
  public void a(GameEvent gameevent, @Nullable Entity entity) {
    a(gameevent, entity, this.aw);
  }
  
  public void a(GameEvent gameevent, BlockPosition blockposition) {
    a(gameevent, this, blockposition);
  }
  
  public void a(GameEvent gameevent) {
    a(gameevent, this.aw);
  }
  
  protected void b(BlockPosition blockposition, IBlockData iblockdata) {
    if (!iblockdata.getMaterial().isLiquid()) {
      IBlockData iblockdata1 = this.t.getType(blockposition.up());
      SoundEffectType soundeffecttype = iblockdata1.a((Tag)TagsBlock.aX) ? iblockdata1.getStepSound() : iblockdata.getStepSound();
      playSound(soundeffecttype.getStepSound(), soundeffecttype.getVolume() * 0.15F, soundeffecttype.getPitch());
    } 
  }
  
  private void b(IBlockData iblockdata) {
    if (iblockdata.a((Tag)TagsBlock.aW) && this.R >= this.aZ + 20) {
      this.aY = (float)(this.aY * Math.pow(0.996999979019165D, (this.R - this.aZ)));
      this.aY = Math.min(1.0F, this.aY + 0.07F);
      float f = 0.5F + this.aY * this.Q.nextFloat() * 1.2F;
      float f1 = 0.1F + this.aY * 1.2F;
      playSound(SoundEffects.x, f1, f);
      this.aZ = this.R;
    } 
  }
  
  protected void d(float f) {
    playSound(getSoundSwim(), f, 1.0F + (this.Q.nextFloat() - this.Q.nextFloat()) * 0.4F);
  }
  
  protected void aE() {}
  
  protected boolean aF() {
    return false;
  }
  
  public void playSound(SoundEffect soundeffect, float f, float f1) {
    if (!isSilent())
      this.t.playSound(null, locX(), locY(), locZ(), soundeffect, getSoundCategory(), f, f1); 
  }
  
  public boolean isSilent() {
    return ((Boolean)this.Y.get(aL)).booleanValue();
  }
  
  public void setSilent(boolean flag) {
    this.Y.set(aL, Boolean.valueOf(flag));
  }
  
  public boolean isNoGravity() {
    return ((Boolean)this.Y.get(aM)).booleanValue();
  }
  
  public void setNoGravity(boolean flag) {
    this.Y.set(aM, Boolean.valueOf(flag));
  }
  
  protected MovementEmission aI() {
    return MovementEmission.d;
  }
  
  public boolean aJ() {
    return false;
  }
  
  protected void a(double d0, boolean flag, IBlockData iblockdata, BlockPosition blockposition) {
    if (flag) {
      if (this.K > 0.0F) {
        iblockdata.getBlock().fallOn(this.t, iblockdata, blockposition, this, this.K);
        if (!iblockdata.a((Tag)TagsBlock.aY))
          a(GameEvent.B); 
      } 
      this.K = 0.0F;
    } else if (d0 < 0.0D) {
      this.K = (float)(this.K - d0);
    } 
  }
  
  public boolean isFireProof() {
    return getEntityType().d();
  }
  
  public boolean a(float f, float f1, DamageSource damagesource) {
    if (isVehicle()) {
      Iterator<Entity> iterator = getPassengers().iterator();
      while (iterator.hasNext()) {
        Entity entity = iterator.next();
        entity.a(f, f1, damagesource);
      } 
    } 
    return false;
  }
  
  public boolean isInWater() {
    return this.S;
  }
  
  private boolean isInRain() {
    BlockPosition blockposition = getChunkCoordinates();
    return !(!this.t.isRainingAt(blockposition) && !this.t.isRainingAt(new BlockPosition(blockposition.getX(), (getBoundingBox()).e, blockposition.getZ())));
  }
  
  private boolean j() {
    return this.t.getType(getChunkCoordinates()).a(Blocks.lq);
  }
  
  public boolean isInWaterOrRain() {
    return !(!isInWater() && !isInRain());
  }
  
  public boolean aN() {
    return !(!isInWater() && !isInRain() && !j());
  }
  
  public boolean aO() {
    return !(!isInWater() && !j());
  }
  
  public boolean aP() {
    return (this.U && isInWater());
  }
  
  public void aQ() {
    if (isSwimming()) {
      setSwimming((isSprinting() && isInWater() && !isPassenger()));
    } else {
      setSwimming((isSprinting() && aP() && !isPassenger() && this.t.getFluid(this.aw).a((Tag)TagsFluid.b)));
    } 
  }
  
  protected boolean aR() {
    this.T.clear();
    aS();
    double d0 = this.t.getDimensionManager().isNether() ? 0.007D : 0.0023333333333333335D;
    boolean flag = a((Tag<FluidType>)TagsFluid.c, d0);
    return !(!isInWater() && !flag);
  }
  
  void aS() {
    if (getVehicle() instanceof EntityBoat) {
      this.S = false;
    } else if (a((Tag<FluidType>)TagsFluid.b, 0.014D)) {
      if (!this.S && !this.X)
        aT(); 
      this.K = 0.0F;
      this.S = true;
      extinguish();
    } else {
      this.S = false;
    } 
  }
  
  private void l() {
    Tag<FluidType> tag;
    this.U = a((Tag<FluidType>)TagsFluid.b);
    this.V = null;
    double d0 = getHeadY() - 0.1111111119389534D;
    Entity entity = getVehicle();
    if (entity instanceof EntityBoat) {
      EntityBoat entityboat = (EntityBoat)entity;
      if (!entityboat.aP() && (entityboat.getBoundingBox()).e >= d0 && (entityboat.getBoundingBox()).b <= d0)
        return; 
    } 
    BlockPosition blockposition = new BlockPosition(locX(), d0, locZ());
    Fluid fluid = this.t.getFluid(blockposition);
    Iterator<Tag> iterator = TagsFluid.b().iterator();
    do {
      if (!iterator.hasNext())
        return; 
      tag = iterator.next();
    } while (!fluid.a(tag));
    double d1 = (blockposition.getY() + fluid.getHeight((IBlockAccess)this.t, blockposition));
    if (d1 > d0)
      this.V = tag; 
  }
  
  protected void aT() {
    Entity entity = (isVehicle() && getRidingPassenger() != null) ? getRidingPassenger() : this;
    float f = (entity == this) ? 0.2F : 0.9F;
    Vec3D vec3d = entity.getMot();
    float f1 = Math.min(1.0F, (float)Math.sqrt(vec3d.b * vec3d.b * 0.20000000298023224D + vec3d.c * vec3d.c + vec3d.d * vec3d.d * 0.20000000298023224D) * f);
    if (f1 < 0.25F) {
      playSound(getSoundSplash(), f1, 1.0F + (this.Q.nextFloat() - this.Q.nextFloat()) * 0.4F);
    } else {
      playSound(getSoundSplashHighSpeed(), f1, 1.0F + (this.Q.nextFloat() - this.Q.nextFloat()) * 0.4F);
    } 
    float f2 = MathHelper.floor(locY());
    int i;
    for (i = 0; i < 1.0F + this.aW.a * 20.0F; i++) {
      double d0 = (this.Q.nextDouble() * 2.0D - 1.0D) * this.aW.a;
      double d1 = (this.Q.nextDouble() * 2.0D - 1.0D) * this.aW.a;
      this.t.addParticle((ParticleParam)Particles.f, locX() + d0, (f2 + 1.0F), locZ() + d1, vec3d.b, vec3d.c - this.Q.nextDouble() * 0.20000000298023224D, vec3d.d);
    } 
    for (i = 0; i < 1.0F + this.aW.a * 20.0F; i++) {
      double d0 = (this.Q.nextDouble() * 2.0D - 1.0D) * this.aW.a;
      double d1 = (this.Q.nextDouble() * 2.0D - 1.0D) * this.aW.a;
      this.t.addParticle((ParticleParam)Particles.ac, locX() + d0, (f2 + 1.0F), locZ() + d1, vec3d.b, vec3d.c, vec3d.d);
    } 
    a(GameEvent.P);
  }
  
  protected IBlockData aU() {
    return this.t.getType(av());
  }
  
  public boolean aV() {
    return (isSprinting() && !isInWater() && !isSpectator() && !isCrouching() && !aX() && isAlive());
  }
  
  protected void aW() {
    int i = MathHelper.floor(locX());
    int j = MathHelper.floor(locY() - 0.20000000298023224D);
    int k = MathHelper.floor(locZ());
    BlockPosition blockposition = new BlockPosition(i, j, k);
    IBlockData iblockdata = this.t.getType(blockposition);
    if (iblockdata.h() != EnumRenderType.a) {
      Vec3D vec3d = getMot();
      this.t.addParticle((ParticleParam)new ParticleParamBlock(Particles.e, iblockdata), locX() + (this.Q.nextDouble() - 0.5D) * this.aW.a, locY() + 0.1D, locZ() + (this.Q.nextDouble() - 0.5D) * this.aW.a, vec3d.b * -4.0D, 1.5D, vec3d.d * -4.0D);
    } 
  }
  
  public boolean a(Tag<FluidType> tag) {
    return (this.V == tag);
  }
  
  public boolean aX() {
    return (!this.X && this.T.getDouble(TagsFluid.c) > 0.0D);
  }
  
  public void a(float f, Vec3D vec3d) {
    Vec3D vec3d1 = a(vec3d, f, getYRot());
    setMot(getMot().e(vec3d1));
  }
  
  private static Vec3D a(Vec3D vec3d, float f, float f1) {
    double d0 = vec3d.g();
    if (d0 < 1.0E-7D)
      return Vec3D.a; 
    Vec3D vec3d1 = ((d0 > 1.0D) ? vec3d.d() : vec3d).a(f);
    float f2 = MathHelper.sin(f1 * 0.017453292F);
    float f3 = MathHelper.cos(f1 * 0.017453292F);
    return new Vec3D(vec3d1.b * f3 - vec3d1.d * f2, vec3d1.c, vec3d1.d * f3 + vec3d1.b * f2);
  }
  
  public float aY() {
    return this.t.e(cW(), dc()) ? this.t.z(new BlockPosition(locX(), getHeadY(), locZ())) : 0.0F;
  }
  
  public void setLocation(double d0, double d1, double d2, float f, float f1) {
    g(d0, d1, d2);
    setYRot(f % 360.0F);
    setXRot(MathHelper.a(f1, -90.0F, 90.0F) % 360.0F);
    this.x = getYRot();
    this.y = getXRot();
  }
  
  public void g(double d0, double d1, double d2) {
    double d3 = MathHelper.a(d0, -3.0E7D, 3.0E7D);
    double d4 = MathHelper.a(d2, -3.0E7D, 3.0E7D);
    this.u = d3;
    this.v = d1;
    this.w = d4;
    setPosition(d3, d1, d4);
    if (this.valid)
      this.t.getChunkAt((int)Math.floor(locX()) >> 4, (int)Math.floor(locZ()) >> 4); 
  }
  
  public void d(Vec3D vec3d) {
    teleportAndSync(vec3d.b, vec3d.c, vec3d.d);
  }
  
  public void teleportAndSync(double d0, double d1, double d2) {
    setPositionRotation(d0, d1, d2, getYRot(), getXRot());
  }
  
  public void setPositionRotation(BlockPosition blockposition, float f, float f1) {
    setPositionRotation(blockposition.getX() + 0.5D, blockposition.getY(), blockposition.getZ() + 0.5D, f, f1);
  }
  
  public void setPositionRotation(double d0, double d1, double d2, float f, float f1) {
    setPositionRaw(d0, d1, d2);
    setYRot(f);
    setXRot(f1);
    aZ();
    ah();
  }
  
  public final void aZ() {
    double d0 = locX();
    double d1 = locY();
    double d2 = locZ();
    this.u = d0;
    this.v = d1;
    this.w = d2;
    this.L = d0;
    this.M = d1;
    this.N = d2;
    this.x = getYRot();
    this.y = getXRot();
  }
  
  public float e(Entity entity) {
    float f = (float)(locX() - entity.locX());
    float f1 = (float)(locY() - entity.locY());
    float f2 = (float)(locZ() - entity.locZ());
    return MathHelper.c(f * f + f1 * f1 + f2 * f2);
  }
  
  public double h(double d0, double d1, double d2) {
    double d3 = locX() - d0;
    double d4 = locY() - d1;
    double d5 = locZ() - d2;
    return d3 * d3 + d4 * d4 + d5 * d5;
  }
  
  public double f(Entity entity) {
    return e(entity.getPositionVector());
  }
  
  public double e(Vec3D vec3d) {
    double d0 = locX() - vec3d.b;
    double d1 = locY() - vec3d.c;
    double d2 = locZ() - vec3d.d;
    return d0 * d0 + d1 * d1 + d2 * d2;
  }
  
  public void pickup(EntityHuman entityhuman) {}
  
  public void collide(Entity entity) {
    if (!isSameVehicle(entity) && 
      !entity.P && !this.P) {
      double d0 = entity.locX() - locX();
      double d1 = entity.locZ() - locZ();
      double d2 = MathHelper.a(d0, d1);
      if (d2 >= 0.009999999776482582D) {
        d2 = Math.sqrt(d2);
        d0 /= d2;
        d1 /= d2;
        double d3 = 1.0D / d2;
        if (d3 > 1.0D)
          d3 = 1.0D; 
        d0 *= d3;
        d1 *= d3;
        d0 *= 0.05000000074505806D;
        d1 *= 0.05000000074505806D;
        if (!isVehicle())
          i(-d0, 0.0D, -d1); 
        if (!entity.isVehicle())
          entity.i(d0, 0.0D, d1); 
      } 
    } 
  }
  
  public void i(double d0, double d1, double d2) {
    setMot(getMot().add(d0, d1, d2));
    this.af = true;
  }
  
  protected void velocityChanged() {
    this.C = true;
  }
  
  public boolean damageEntity(DamageSource damagesource, float f) {
    if (isInvulnerable(damagesource))
      return false; 
    velocityChanged();
    return false;
  }
  
  public final Vec3D e(float f) {
    return b(f(f), g(f));
  }
  
  public float f(float f) {
    return (f == 1.0F) ? getXRot() : MathHelper.h(f, this.y, getXRot());
  }
  
  public float g(float f) {
    return (f == 1.0F) ? getYRot() : MathHelper.h(f, this.x, getYRot());
  }
  
  protected final Vec3D b(float f, float f1) {
    float f2 = f * 0.017453292F;
    float f3 = -f1 * 0.017453292F;
    float f4 = MathHelper.cos(f3);
    float f5 = MathHelper.sin(f3);
    float f6 = MathHelper.cos(f2);
    float f7 = MathHelper.sin(f2);
    return new Vec3D((f5 * f6), -f7, (f4 * f6));
  }
  
  public final Vec3D h(float f) {
    return c(f(f), g(f));
  }
  
  protected final Vec3D c(float f, float f1) {
    return b(f - 90.0F, f1);
  }
  
  public final Vec3D bb() {
    return new Vec3D(locX(), getHeadY(), locZ());
  }
  
  public final Vec3D i(float f) {
    double d0 = MathHelper.d(f, this.u, locX());
    double d1 = MathHelper.d(f, this.v, locY()) + getHeadHeight();
    double d2 = MathHelper.d(f, this.w, locZ());
    return new Vec3D(d0, d1, d2);
  }
  
  public Vec3D j(float f) {
    return i(f);
  }
  
  public final Vec3D k(float f) {
    double d0 = MathHelper.d(f, this.u, locX());
    double d1 = MathHelper.d(f, this.v, locY());
    double d2 = MathHelper.d(f, this.w, locZ());
    return new Vec3D(d0, d1, d2);
  }
  
  public MovingObjectPosition a(double d0, float f, boolean flag) {
    Vec3D vec3d = i(f);
    Vec3D vec3d1 = e(f);
    Vec3D vec3d2 = vec3d.add(vec3d1.b * d0, vec3d1.c * d0, vec3d1.d * d0);
    return (MovingObjectPosition)this.t.rayTrace(new RayTrace(vec3d, vec3d2, RayTrace.BlockCollisionOption.b, flag ? RayTrace.FluidCollisionOption.c : RayTrace.FluidCollisionOption.a, this));
  }
  
  public boolean isInteractable() {
    return false;
  }
  
  public boolean isCollidable() {
    return false;
  }
  
  public boolean canCollideWithBukkit(Entity entity) {
    return isCollidable();
  }
  
  public void a(Entity entity, int i, DamageSource damagesource) {
    if (entity instanceof EntityPlayer)
      CriterionTriggers.c.a((EntityPlayer)entity, this, damagesource); 
  }
  
  public boolean j(double d0, double d1, double d2) {
    double d3 = locX() - d0;
    double d4 = locY() - d1;
    double d5 = locZ() - d2;
    double d6 = d3 * d3 + d4 * d4 + d5 * d5;
    return a(d6);
  }
  
  public boolean a(double d0) {
    double d1 = getBoundingBox().a();
    if (Double.isNaN(d1))
      d1 = 1.0D; 
    d1 *= 64.0D * aq;
    return (d0 < d1 * d1);
  }
  
  public boolean d(NBTTagCompound nbttagcompound) {
    if (this.aB != null && !this.aB.b())
      return false; 
    String s = getSaveID();
    if (!this.persist || s == null)
      return false; 
    nbttagcompound.setString("id", s);
    save(nbttagcompound);
    return true;
  }
  
  public boolean e(NBTTagCompound nbttagcompound) {
    return isPassenger() ? false : d(nbttagcompound);
  }
  
  public NBTTagCompound save(NBTTagCompound nbttagcompound) {
    try {
      if (this.au != null) {
        nbttagcompound.set("Pos", (NBTBase)newDoubleList(new double[] { this.au.locX(), locY(), this.au.locZ() }));
      } else {
        nbttagcompound.set("Pos", (NBTBase)newDoubleList(new double[] { locX(), locY(), locZ() }));
      } 
      Vec3D vec3d = getMot();
      nbttagcompound.set("Motion", (NBTBase)newDoubleList(new double[] { vec3d.b, vec3d.c, vec3d.d }));
      if (Float.isNaN(this.ay))
        this.ay = 0.0F; 
      if (Float.isNaN(this.az))
        this.az = 0.0F; 
      nbttagcompound.set("Rotation", (NBTBase)newFloatList(new float[] { getYRot(), getXRot() }));
      nbttagcompound.setFloat("FallDistance", this.K);
      nbttagcompound.setShort("Fire", (short)this.aD);
      nbttagcompound.setShort("Air", (short)getAirTicks());
      nbttagcompound.setBoolean("OnGround", this.z);
      nbttagcompound.setBoolean("Invulnerable", this.aR);
      nbttagcompound.setInt("PortalCooldown", this.aQ);
      nbttagcompound.a("UUID", getUniqueID());
      nbttagcompound.setLong("WorldUUIDLeast", ((WorldServer)this.t).getWorld().getUID().getLeastSignificantBits());
      nbttagcompound.setLong("WorldUUIDMost", ((WorldServer)this.t).getWorld().getUID().getMostSignificantBits());
      nbttagcompound.setInt("Bukkit.updateLevel", 2);
      if (!this.persist)
        nbttagcompound.setBoolean("Bukkit.persist", this.persist); 
      if (this.persistentInvisibility)
        nbttagcompound.setBoolean("Bukkit.invisible", this.persistentInvisibility); 
      nbttagcompound.setInt("Spigot.ticksLived", this.R);
      IChatBaseComponent ichatbasecomponent = getCustomName();
      if (ichatbasecomponent != null)
        nbttagcompound.setString("CustomName", IChatBaseComponent.ChatSerializer.a(ichatbasecomponent)); 
      if (getCustomNameVisible())
        nbttagcompound.setBoolean("CustomNameVisible", getCustomNameVisible()); 
      if (isSilent())
        nbttagcompound.setBoolean("Silent", isSilent()); 
      if (isNoGravity())
        nbttagcompound.setBoolean("NoGravity", isNoGravity()); 
      if (this.aS)
        nbttagcompound.setBoolean("Glowing", true); 
      int i = getTicksFrozen();
      if (i > 0)
        nbttagcompound.setInt("TicksFrozen", getTicksFrozen()); 
      if (this.ba)
        nbttagcompound.setBoolean("HasVisualFire", this.ba); 
      if (!this.aT.isEmpty()) {
        NBTTagList nbttaglist = new NBTTagList();
        Iterator<String> iterator = this.aT.iterator();
        while (iterator.hasNext()) {
          String s = iterator.next();
          nbttaglist.add(NBTTagString.a(s));
        } 
        nbttagcompound.set("Tags", (NBTBase)nbttaglist);
      } 
      saveData(nbttagcompound);
      if (isVehicle()) {
        NBTTagList nbttaglist = new NBTTagList();
        Iterator<Entity> iterator = getPassengers().iterator();
        while (iterator.hasNext()) {
          Entity entity = iterator.next();
          NBTTagCompound nbttagcompound1 = new NBTTagCompound();
          if (entity.d(nbttagcompound1))
            nbttaglist.add(nbttagcompound1); 
        } 
        if (!nbttaglist.isEmpty())
          nbttagcompound.set("Passengers", (NBTBase)nbttaglist); 
      } 
      if (this.bukkitEntity != null)
        this.bukkitEntity.storeBukkitValues(nbttagcompound); 
      return nbttagcompound;
    } catch (Throwable throwable) {
      CrashReport crashreport = CrashReport.a(throwable, "Saving entity NBT");
      CrashReportSystemDetails crashreportsystemdetails = crashreport.a("Entity being saved");
      appendEntityCrashDetails(crashreportsystemdetails);
      throw new ReportedException(crashreport);
    } 
  }
  
  public void load(NBTTagCompound nbttagcompound) {
    try {
      NBTTagList nbttaglist = nbttagcompound.getList("Pos", 6);
      NBTTagList nbttaglist1 = nbttagcompound.getList("Motion", 6);
      NBTTagList nbttaglist2 = nbttagcompound.getList("Rotation", 5);
      double d0 = nbttaglist1.h(0);
      double d1 = nbttaglist1.h(1);
      double d2 = nbttaglist1.h(2);
      setMot((Math.abs(d0) > 10.0D) ? 0.0D : d0, (Math.abs(d1) > 10.0D) ? 0.0D : d1, (Math.abs(d2) > 10.0D) ? 0.0D : d2);
      setPositionRaw(nbttaglist.h(0), MathHelper.a(nbttaglist.h(1), -2.0E7D, 2.0E7D), nbttaglist.h(2));
      setYRot(nbttaglist2.i(0));
      setXRot(nbttaglist2.i(1));
      aZ();
      setHeadRotation(getYRot());
      m(getYRot());
      this.K = nbttagcompound.getFloat("FallDistance");
      this.aD = nbttagcompound.getShort("Fire");
      if (nbttagcompound.hasKey("Air"))
        setAirTicks(nbttagcompound.getShort("Air")); 
      this.z = nbttagcompound.getBoolean("OnGround");
      this.aR = nbttagcompound.getBoolean("Invulnerable");
      this.aQ = nbttagcompound.getInt("PortalCooldown");
      if (nbttagcompound.b("UUID")) {
        this.aj = nbttagcompound.a("UUID");
        this.ak = this.aj.toString();
      } 
      if (Double.isFinite(locX()) && Double.isFinite(locY()) && Double.isFinite(locZ())) {
        if (Double.isFinite(getYRot()) && Double.isFinite(getXRot())) {
          ah();
          setYawPitch(getYRot(), getXRot());
          if (nbttagcompound.hasKeyOfType("CustomName", 8)) {
            String s = nbttagcompound.getString("CustomName");
            try {
              setCustomName((IChatBaseComponent)IChatBaseComponent.ChatSerializer.a(s));
            } catch (Exception exception) {
              g.warn("Failed to parse entity custom name {}", s, exception);
            } 
          } 
          setCustomNameVisible(nbttagcompound.getBoolean("CustomNameVisible"));
          setSilent(nbttagcompound.getBoolean("Silent"));
          setNoGravity(nbttagcompound.getBoolean("NoGravity"));
          setGlowingTag(nbttagcompound.getBoolean("Glowing"));
          setTicksFrozen(nbttagcompound.getInt("TicksFrozen"));
          this.ba = nbttagcompound.getBoolean("HasVisualFire");
          if (nbttagcompound.hasKeyOfType("Tags", 9)) {
            this.aT.clear();
            NBTTagList nbttaglist3 = nbttagcompound.getList("Tags", 8);
            int i = Math.min(nbttaglist3.size(), 1024);
            for (int j = 0; j < i; j++)
              this.aT.add(nbttaglist3.getString(j)); 
          } 
          loadData(nbttagcompound);
          if (be())
            ah(); 
        } else {
          throw new IllegalStateException("Entity has invalid rotation");
        } 
      } else {
        throw new IllegalStateException("Entity has invalid position");
      } 
      if (this instanceof EntityLiving) {
        EntityLiving entity = (EntityLiving)this;
        this.R = nbttagcompound.getInt("Spigot.ticksLived");
        if (entity instanceof EntityTameableAnimal && !isLevelAtLeast(nbttagcompound, 2) && !nbttagcompound.getBoolean("PersistenceRequired")) {
          EntityInsentient entityinsentient = (EntityInsentient)entity;
          entityinsentient.setPersistenceRequired(!entityinsentient.isTypeNotPersistent(0.0D));
        } 
      } 
      this.persist = !(nbttagcompound.hasKey("Bukkit.persist") && !nbttagcompound.getBoolean("Bukkit.persist"));
      if (this instanceof EntityPlayer) {
        CraftWorld craftWorld;
        Server server = Bukkit.getServer();
        World bworld = null;
        String worldName = nbttagcompound.getString("world");
        if (nbttagcompound.hasKey("WorldUUIDMost") && nbttagcompound.hasKey("WorldUUIDLeast")) {
          UUID uid = new UUID(nbttagcompound.getLong("WorldUUIDMost"), nbttagcompound.getLong("WorldUUIDLeast"));
          bworld = server.getWorld(uid);
        } else {
          bworld = server.getWorld(worldName);
        } 
        if (bworld == null)
          craftWorld = ((CraftServer)server).getServer().getWorldServer(World.f).getWorld(); 
        ((EntityPlayer)this).spawnIn((craftWorld == null) ? null : craftWorld.getHandle());
      } 
      getBukkitEntity().readBukkitValues(nbttagcompound);
      if (nbttagcompound.hasKey("Bukkit.invisible")) {
        boolean bukkitInvisible = nbttagcompound.getBoolean("Bukkit.invisible");
        setInvisible(bukkitInvisible);
        this.persistentInvisibility = bukkitInvisible;
      } 
    } catch (Throwable throwable) {
      CrashReport crashreport = CrashReport.a(throwable, "Loading entity NBT");
      CrashReportSystemDetails crashreportsystemdetails = crashreport.a("Entity being loaded");
      appendEntityCrashDetails(crashreportsystemdetails);
      throw new ReportedException(crashreport);
    } 
  }
  
  protected boolean be() {
    return true;
  }
  
  @Nullable
  public final String getSaveID() {
    EntityTypes<?> entitytypes = getEntityType();
    MinecraftKey minecraftkey = EntityTypes.getName(entitytypes);
    return (entitytypes.b() && minecraftkey != null) ? minecraftkey.toString() : null;
  }
  
  protected NBTTagList newDoubleList(double... adouble) {
    NBTTagList nbttaglist = new NBTTagList();
    double[] adouble1 = adouble;
    int i = adouble.length;
    for (int j = 0; j < i; j++) {
      double d0 = adouble1[j];
      nbttaglist.add(NBTTagDouble.a(d0));
    } 
    return nbttaglist;
  }
  
  protected NBTTagList newFloatList(float... afloat) {
    NBTTagList nbttaglist = new NBTTagList();
    float[] afloat1 = afloat;
    int i = afloat.length;
    for (int j = 0; j < i; j++) {
      float f = afloat1[j];
      nbttaglist.add(NBTTagFloat.a(f));
    } 
    return nbttaglist;
  }
  
  @Nullable
  public EntityItem a(IMaterial imaterial) {
    return a(imaterial, 0);
  }
  
  @Nullable
  public EntityItem a(IMaterial imaterial, int i) {
    return a(new ItemStack(imaterial), i);
  }
  
  @Nullable
  public EntityItem b(ItemStack itemstack) {
    return a(itemstack, 0.0F);
  }
  
  @Nullable
  public EntityItem a(ItemStack itemstack, float f) {
    if (itemstack.isEmpty())
      return null; 
    if (this.t.y)
      return null; 
    if (this instanceof EntityLiving && !((EntityLiving)this).forceDrops) {
      ((EntityLiving)this).drops.add(CraftItemStack.asBukkitCopy(itemstack));
      return null;
    } 
    EntityItem entityitem = new EntityItem(this.t, locX(), locY() + f, locZ(), itemstack);
    entityitem.defaultPickupDelay();
    EntityDropItemEvent event = new EntityDropItemEvent((org.bukkit.entity.Entity)getBukkitEntity(), (Item)entityitem.getBukkitEntity());
    Bukkit.getPluginManager().callEvent((Event)event);
    if (event.isCancelled())
      return null; 
    this.t.addEntity((Entity)entityitem);
    return entityitem;
  }
  
  public boolean isAlive() {
    return !isRemoved();
  }
  
  public boolean inBlock() {
    if (this.P)
      return false; 
    float f = this.aW.a * 0.8F;
    AxisAlignedBB axisalignedbb = AxisAlignedBB.a(bb(), f, 1.0E-6D, f);
    return this.t.b(this, axisalignedbb, (iblockdata, blockposition) -> iblockdata.o((IBlockAccess)this.t, blockposition))
      
      .findAny().isPresent();
  }
  
  public EnumInteractionResult a(EntityHuman entityhuman, EnumHand enumhand) {
    return EnumInteractionResult.d;
  }
  
  public boolean h(Entity entity) {
    return (entity.bi() && !isSameVehicle(entity));
  }
  
  public boolean bi() {
    return false;
  }
  
  public void passengerTick() {
    setMot(Vec3D.a);
    tick();
    if (isPassenger())
      getVehicle().i(this); 
  }
  
  public void i(Entity entity) {
    a(entity, Entity::setPosition);
  }
  
  private void a(Entity entity, MoveFunction entity_movefunction) {
    if (u(entity)) {
      double d0 = locY() + bl() + entity.bk();
      entity_movefunction.accept(entity, locX(), d0, locZ());
    } 
  }
  
  public void j(Entity entity) {}
  
  public double bk() {
    return 0.0D;
  }
  
  public double bl() {
    return this.aW.b * 0.75D;
  }
  
  public boolean startRiding(Entity entity) {
    return a(entity, false);
  }
  
  public boolean bm() {
    return this instanceof EntityLiving;
  }
  
  public boolean a(Entity entity, boolean flag) {
    if (entity == this.au)
      return false; 
    for (Entity entity1 = entity; entity1.au != null; entity1 = entity1.au) {
      if (entity1.au == this)
        return false; 
    } 
    if (!flag && (!l(entity) || !entity.o(this)))
      return false; 
    if (isPassenger())
      stopRiding(); 
    setPose(EntityPose.a);
    this.au = entity;
    if (!this.au.addPassenger(this))
      this.au = null; 
    entity.n().filter(entity2 -> entity2 instanceof EntityPlayer)
      
      .forEach(entity2 -> CriterionTriggers.Q.a((EntityPlayer)entity2));
    return true;
  }
  
  protected boolean l(Entity entity) {
    return (!isSneaking() && this.s <= 0);
  }
  
  protected boolean c(EntityPose entitypose) {
    return this.t.getCubes(this, d(entitypose).shrink(1.0E-7D));
  }
  
  public void ejectPassengers() {
    for (int i = this.at.size() - 1; i >= 0; i--)
      ((Entity)this.at.get(i)).stopRiding(); 
  }
  
  public void bo() {
    if (this.au != null) {
      Entity entity = this.au;
      this.au = null;
      if (!entity.removePassenger(this))
        this.au = entity; 
    } 
  }
  
  public void stopRiding() {
    bo();
  }
  
  protected boolean addPassenger(Entity entity) {
    if (entity.getVehicle() != this)
      throw new IllegalStateException("Use x.startRiding(y), not y.addPassenger(x)"); 
    Preconditions.checkState(!entity.at.contains(this), "Circular entity riding! %s %s", this, entity);
    CraftEntity craft = (CraftEntity)entity.getBukkitEntity().getVehicle();
    Entity orig = (craft == null) ? null : craft.getHandle();
    if (getBukkitEntity() instanceof Vehicle && entity.getBukkitEntity() instanceof LivingEntity) {
      VehicleEnterEvent vehicleEnterEvent = new VehicleEnterEvent(
          (Vehicle)getBukkitEntity(), 
          (org.bukkit.entity.Entity)entity.getBukkitEntity());
      if (this.valid)
        Bukkit.getPluginManager().callEvent((Event)vehicleEnterEvent); 
      CraftEntity craftn = (CraftEntity)entity.getBukkitEntity().getVehicle();
      Entity n = (craftn == null) ? null : craftn.getHandle();
      if (vehicleEnterEvent.isCancelled() || n != orig)
        return false; 
    } 
    EntityMountEvent event = new EntityMountEvent((org.bukkit.entity.Entity)entity.getBukkitEntity(), (org.bukkit.entity.Entity)getBukkitEntity());
    if (this.valid)
      Bukkit.getPluginManager().callEvent((Event)event); 
    if (event.isCancelled())
      return false; 
    if (this.at.isEmpty()) {
      this.at = ImmutableList.of(entity);
    } else {
      List<Entity> list = Lists.newArrayList((Iterable)this.at);
      if (!this.t.y && entity instanceof EntityHuman && !(getRidingPassenger() instanceof EntityHuman)) {
        list.add(0, entity);
      } else {
        list.add(entity);
      } 
      this.at = ImmutableList.copyOf(list);
    } 
    return true;
  }
  
  protected boolean removePassenger(Entity entity) {
    if (entity.getVehicle() == this)
      throw new IllegalStateException("Use x.stopRiding(y), not y.removePassenger(x)"); 
    CraftEntity craft = (CraftEntity)entity.getBukkitEntity().getVehicle();
    Entity orig = (craft == null) ? null : craft.getHandle();
    if (getBukkitEntity() instanceof Vehicle && entity.getBukkitEntity() instanceof LivingEntity) {
      VehicleExitEvent vehicleExitEvent = new VehicleExitEvent(
          (Vehicle)getBukkitEntity(), 
          (LivingEntity)entity.getBukkitEntity());
      if (this.valid)
        Bukkit.getPluginManager().callEvent((Event)vehicleExitEvent); 
      CraftEntity craftn = (CraftEntity)entity.getBukkitEntity().getVehicle();
      Entity n = (craftn == null) ? null : craftn.getHandle();
      if (vehicleExitEvent.isCancelled() || n != orig)
        return false; 
    } 
    EntityDismountEvent event = new EntityDismountEvent((org.bukkit.entity.Entity)entity.getBukkitEntity(), (org.bukkit.entity.Entity)getBukkitEntity());
    if (this.valid)
      Bukkit.getPluginManager().callEvent((Event)event); 
    if (event.isCancelled())
      return false; 
    if (this.at.size() == 1 && this.at.get(0) == entity) {
      this.at = ImmutableList.of();
    } else {
      this.at = (ImmutableList<Entity>)this.at.stream().filter(entity1 -> (entity1 != paramEntity1))
        
        .collect(ImmutableList.toImmutableList());
    } 
    entity.s = 60;
    return true;
  }
  
  protected boolean o(Entity entity) {
    return this.at.isEmpty();
  }
  
  public void a(double d0, double d1, double d2, float f, float f1, int i, boolean flag) {
    setPosition(d0, d1, d2);
    setYawPitch(f, f1);
  }
  
  public void a(float f, int i) {
    setHeadRotation(f);
  }
  
  public float bp() {
    return 0.0F;
  }
  
  public Vec3D getLookDirection() {
    return b(getXRot(), getYRot());
  }
  
  public Vec2F br() {
    return new Vec2F(getXRot(), getYRot());
  }
  
  public Vec3D bs() {
    return Vec3D.a(br());
  }
  
  public void d(BlockPosition blockposition) {
    if (al()) {
      resetPortalCooldown();
    } else {
      if (!this.t.y && !blockposition.equals(this.ai))
        this.ai = blockposition.immutableCopy(); 
      this.ag = true;
    } 
  }
  
  protected void doPortalTick() {
    if (this.t instanceof WorldServer) {
      int i = am();
      WorldServer worldserver = (WorldServer)this.t;
      if (this.ag) {
        MinecraftServer minecraftserver = worldserver.getMinecraftServer();
        ResourceKey<World> resourcekey = (this.t.getTypeKey() == DimensionManager.l) ? World.f : World.g;
        WorldServer worldserver1 = minecraftserver.getWorldServer(resourcekey);
        if (!isPassenger() && this.ah++ >= i) {
          this.t.getMethodProfiler().enter("portal");
          this.ah = i;
          resetPortalCooldown();
          if (this instanceof EntityPlayer) {
            ((EntityPlayer)this).b(worldserver1, PlayerTeleportEvent.TeleportCause.NETHER_PORTAL);
          } else {
            b(worldserver1);
          } 
          this.t.getMethodProfiler().exit();
        } 
        this.ag = false;
      } else {
        if (this.ah > 0)
          this.ah -= 4; 
        if (this.ah < 0)
          this.ah = 0; 
      } 
      E();
    } 
  }
  
  public int getDefaultPortalCooldown() {
    return 300;
  }
  
  public void k(double d0, double d1, double d2) {
    setMot(d0, d1, d2);
  }
  
  public void a(byte b0) {
    switch (b0) {
      case 53:
        BlockHoney.a(this);
        break;
    } 
  }
  
  public void bv() {}
  
  public Iterable<ItemStack> bw() {
    return c;
  }
  
  public Iterable<ItemStack> getArmorItems() {
    return c;
  }
  
  public Iterable<ItemStack> by() {
    return Iterables.concat(bw(), getArmorItems());
  }
  
  public void setSlot(EnumItemSlot enumitemslot, ItemStack itemstack) {}
  
  public boolean isBurning() {
    boolean flag = (this.t != null && this.t.y);
    return (!isFireProof() && (this.aD > 0 || (flag && getFlag(0))));
  }
  
  public boolean isPassenger() {
    return (getVehicle() != null);
  }
  
  public boolean isVehicle() {
    return !this.at.isEmpty();
  }
  
  public boolean bC() {
    return true;
  }
  
  public void setSneaking(boolean flag) {
    setFlag(1, flag);
  }
  
  public boolean isSneaking() {
    return getFlag(1);
  }
  
  public boolean bE() {
    return isSneaking();
  }
  
  public boolean bF() {
    return isSneaking();
  }
  
  public boolean bG() {
    return isSneaking();
  }
  
  public boolean bH() {
    return isSneaking();
  }
  
  public boolean isCrouching() {
    return (getPose() == EntityPose.f);
  }
  
  public boolean isSprinting() {
    return getFlag(3);
  }
  
  public void setSprinting(boolean flag) {
    setFlag(3, flag);
  }
  
  public boolean isSwimming() {
    return getFlag(4);
  }
  
  public boolean bL() {
    return (getPose() == EntityPose.d);
  }
  
  public boolean bM() {
    return (bL() && !isInWater());
  }
  
  public void setSwimming(boolean flag) {
    if (this.valid && isSwimming() != flag && this instanceof EntityLiving && 
      CraftEventFactory.callToggleSwimEvent((EntityLiving)this, flag).isCancelled())
      return; 
    setFlag(4, flag);
  }
  
  public final boolean hasGlowingTag() {
    return this.aS;
  }
  
  public final void setGlowingTag(boolean flag) {
    this.aS = flag;
    setFlag(6, isCurrentlyGlowing());
  }
  
  public boolean isCurrentlyGlowing() {
    return this.t.isClientSide() ? getFlag(6) : this.aS;
  }
  
  public boolean isInvisible() {
    return getFlag(5);
  }
  
  public boolean c(EntityHuman entityhuman) {
    if (entityhuman.isSpectator())
      return false; 
    ScoreboardTeamBase scoreboardteambase = getScoreboardTeam();
    return (scoreboardteambase != null && entityhuman != null && entityhuman.getScoreboardTeam() == scoreboardteambase && scoreboardteambase.canSeeFriendlyInvisibles()) ? false : isInvisible();
  }
  
  @Nullable
  public GameEventListenerRegistrar bQ() {
    return null;
  }
  
  @Nullable
  public ScoreboardTeamBase getScoreboardTeam() {
    return (ScoreboardTeamBase)this.t.getScoreboard().getPlayerTeam(getName());
  }
  
  public boolean p(Entity entity) {
    return a(entity.getScoreboardTeam());
  }
  
  public boolean a(ScoreboardTeamBase scoreboardteambase) {
    return (getScoreboardTeam() != null) ? getScoreboardTeam().isAlly(scoreboardteambase) : false;
  }
  
  public void setInvisible(boolean flag) {
    if (!this.persistentInvisibility)
      setFlag(5, flag); 
  }
  
  public boolean getFlag(int i) {
    return ((((Byte)this.Y.get(Z)).byteValue() & 1 << i) != 0);
  }
  
  public void setFlag(int i, boolean flag) {
    byte b0 = ((Byte)this.Y.get(Z)).byteValue();
    if (flag) {
      this.Y.set(Z, Byte.valueOf((byte)(b0 | 1 << i)));
    } else {
      this.Y.set(Z, Byte.valueOf((byte)(b0 & (1 << i ^ 0xFFFFFFFF))));
    } 
  }
  
  public int bS() {
    return 300;
  }
  
  public int getAirTicks() {
    return ((Integer)this.Y.get(aI)).intValue();
  }
  
  public void setAirTicks(int i) {
    EntityAirChangeEvent event = new EntityAirChangeEvent((org.bukkit.entity.Entity)getBukkitEntity(), i);
    if (this.valid)
      event.getEntity().getServer().getPluginManager().callEvent((Event)event); 
    if (event.isCancelled())
      return; 
    this.Y.set(aI, Integer.valueOf(event.getAmount()));
  }
  
  public int getTicksFrozen() {
    return ((Integer)this.Y.get(aN)).intValue();
  }
  
  public void setTicksFrozen(int i) {
    this.Y.set(aN, Integer.valueOf(i));
  }
  
  public float bV() {
    int i = getTicksRequiredToFreeze();
    return Math.min(getTicksFrozen(), i) / i;
  }
  
  public boolean isFullyFrozen() {
    return (getTicksFrozen() >= getTicksRequiredToFreeze());
  }
  
  public int getTicksRequiredToFreeze() {
    return 140;
  }
  
  public void onLightningStrike(WorldServer worldserver, EntityLightning entitylightning) {
    setFireTicks(this.aD + 1);
    CraftEntity craftEntity1 = getBukkitEntity();
    CraftEntity craftEntity2 = entitylightning.getBukkitEntity();
    PluginManager pluginManager = Bukkit.getPluginManager();
    if (this.aD == 0) {
      EntityCombustByEntityEvent entityCombustEvent = new EntityCombustByEntityEvent((org.bukkit.entity.Entity)craftEntity2, (org.bukkit.entity.Entity)craftEntity1, 8);
      pluginManager.callEvent((Event)entityCombustEvent);
      if (!entityCombustEvent.isCancelled())
        setOnFire(entityCombustEvent.getDuration(), false); 
    } 
    if (craftEntity1 instanceof Hanging) {
      HangingBreakByEntityEvent hangingEvent = new HangingBreakByEntityEvent((Hanging)craftEntity1, (org.bukkit.entity.Entity)craftEntity2);
      pluginManager.callEvent((Event)hangingEvent);
      if (hangingEvent.isCancelled())
        return; 
    } 
    if (isFireProof())
      return; 
    CraftEventFactory.entityDamage = entitylightning;
    if (!damageEntity(DamageSource.b, 5.0F)) {
      CraftEventFactory.entityDamage = null;
      return;
    } 
  }
  
  public void k(boolean flag) {
    double d0;
    Vec3D vec3d = getMot();
    if (flag) {
      d0 = Math.max(-0.9D, vec3d.c - 0.03D);
    } else {
      d0 = Math.min(1.8D, vec3d.c + 0.1D);
    } 
    setMot(vec3d.b, d0, vec3d.d);
  }
  
  public void l(boolean flag) {
    double d0;
    Vec3D vec3d = getMot();
    if (flag) {
      d0 = Math.max(-0.3D, vec3d.c - 0.03D);
    } else {
      d0 = Math.min(0.7D, vec3d.c + 0.06D);
    } 
    setMot(vec3d.b, d0, vec3d.d);
    this.K = 0.0F;
  }
  
  public void a(WorldServer worldserver, EntityLiving entityliving) {}
  
  protected void l(double d0, double d1, double d2) {
    BlockPosition blockposition = new BlockPosition(d0, d1, d2);
    Vec3D vec3d = new Vec3D(d0 - blockposition.getX(), d1 - blockposition.getY(), d2 - blockposition.getZ());
    BlockPosition.MutableBlockPosition blockposition_mutableblockposition = new BlockPosition.MutableBlockPosition();
    EnumDirection enumdirection = EnumDirection.b;
    double d3 = Double.MAX_VALUE;
    EnumDirection[] aenumdirection = { EnumDirection.c, EnumDirection.d, EnumDirection.e, EnumDirection.f, EnumDirection.b };
    int i = aenumdirection.length;
    for (int j = 0; j < i; j++) {
      EnumDirection enumdirection1 = aenumdirection[j];
      blockposition_mutableblockposition.a((BaseBlockPosition)blockposition, enumdirection1);
      if (!this.t.getType((BlockPosition)blockposition_mutableblockposition).r((IBlockAccess)this.t, (BlockPosition)blockposition_mutableblockposition)) {
        double d4 = vec3d.a(enumdirection1.n());
        double d5 = (enumdirection1.e() == EnumDirection.EnumAxisDirection.a) ? (1.0D - d4) : d4;
        if (d5 < d3) {
          d3 = d5;
          enumdirection = enumdirection1;
        } 
      } 
    } 
    float f = this.Q.nextFloat() * 0.2F + 0.1F;
    float f1 = enumdirection.e().a();
    Vec3D vec3d1 = getMot().a(0.75D);
    if (enumdirection.n() == EnumDirection.EnumAxis.a) {
      setMot((f1 * f), vec3d1.c, vec3d1.d);
    } else if (enumdirection.n() == EnumDirection.EnumAxis.b) {
      setMot(vec3d1.b, (f1 * f), vec3d1.d);
    } else if (enumdirection.n() == EnumDirection.EnumAxis.c) {
      setMot(vec3d1.b, vec3d1.c, (f1 * f));
    } 
  }
  
  public void a(IBlockData iblockdata, Vec3D vec3d) {
    this.K = 0.0F;
    this.D = vec3d;
  }
  
  private static IChatBaseComponent b(IChatBaseComponent ichatbasecomponent) {
    IChatMutableComponent ichatmutablecomponent = ichatbasecomponent.g().setChatModifier(ichatbasecomponent.getChatModifier().setChatClickable(null));
    Iterator<IChatBaseComponent> iterator = ichatbasecomponent.getSiblings().iterator();
    while (iterator.hasNext()) {
      IChatBaseComponent ichatbasecomponent1 = iterator.next();
      ichatmutablecomponent.addSibling(b(ichatbasecomponent1));
    } 
    return (IChatBaseComponent)ichatmutablecomponent;
  }
  
  public IChatBaseComponent getDisplayName() {
    IChatBaseComponent ichatbasecomponent = getCustomName();
    return (ichatbasecomponent != null) ? b(ichatbasecomponent) : bY();
  }
  
  protected IChatBaseComponent bY() {
    return this.ar.h();
  }
  
  public boolean q(Entity entity) {
    return (this == entity);
  }
  
  public float getHeadRotation() {
    return 0.0F;
  }
  
  public void setHeadRotation(float f) {}
  
  public void m(float f) {}
  
  public boolean ca() {
    return true;
  }
  
  public boolean r(Entity entity) {
    return false;
  }
  
  public String toString() {
    return String.format(Locale.ROOT, "%s['%s'/%d, l='%s', x=%.2f, y=%.2f, z=%.2f]", new Object[] { getClass().getSimpleName(), getDisplayName().getString(), Integer.valueOf(this.as), (this.t == null) ? "~NULL~" : this.t.toString(), Double.valueOf(locX()), Double.valueOf(locY()), Double.valueOf(locZ()) });
  }
  
  public boolean isInvulnerable(DamageSource damagesource) {
    return !(!isRemoved() && (!this.aR || damagesource == DamageSource.m || damagesource.B()));
  }
  
  public boolean isInvulnerable() {
    return this.aR;
  }
  
  public void setInvulnerable(boolean flag) {
    this.aR = flag;
  }
  
  public void s(Entity entity) {
    setPositionRotation(entity.locX(), entity.locY(), entity.locZ(), entity.getYRot(), entity.getXRot());
  }
  
  public void t(Entity entity) {
    NBTTagCompound nbttagcompound = entity.save(new NBTTagCompound());
    nbttagcompound.remove("Dimension");
    load(nbttagcompound);
    this.aQ = entity.aQ;
    this.ai = entity.ai;
  }
  
  @Nullable
  public Entity b(WorldServer worldserver) {
    return teleportTo(worldserver, null);
  }
  
  @Nullable
  public Entity teleportTo(WorldServer worldserver, BlockPosition location) {
    if (this.t instanceof WorldServer && !isRemoved()) {
      this.t.getMethodProfiler().enter("changeDimension");
      if (worldserver == null)
        return null; 
      this.t.getMethodProfiler().enter("reposition");
      ShapeDetectorShape shapedetectorshape = (location == null) ? a(worldserver) : new ShapeDetectorShape(new Vec3D(location.getX(), location.getY(), location.getZ()), Vec3D.a, this.ay, this.az, worldserver, null);
      if (shapedetectorshape == null)
        return null; 
      worldserver = shapedetectorshape.world;
      decouple();
      this.t.getMethodProfiler().exitEnter("reloading");
      Entity entity = (Entity)getEntityType().a((World)worldserver);
      if (entity != null) {
        entity.t(this);
        entity.setPositionRotation(shapedetectorshape.a.b, shapedetectorshape.a.c, shapedetectorshape.a.d, shapedetectorshape.c, entity.getXRot());
        entity.setMot(shapedetectorshape.b);
        worldserver.addEntityTeleport(entity);
        if (worldserver.getTypeKey() == DimensionManager.m)
          WorldServer.a(worldserver, this); 
        getBukkitEntity().setHandle(entity);
        entity.bukkitEntity = getBukkitEntity();
        if (this instanceof EntityInsentient)
          ((EntityInsentient)this).unleash(true, false); 
      } 
      cc();
      this.t.getMethodProfiler().exit();
      ((WorldServer)this.t).resetEmptyTime();
      worldserver.resetEmptyTime();
      this.t.getMethodProfiler().exit();
      return entity;
    } 
    return null;
  }
  
  protected void cc() {
    setRemoved(RemovalReason.e);
  }
  
  @Nullable
  protected ShapeDetectorShape a(WorldServer worldserver) {
    if (worldserver == null)
      return null; 
    boolean flag = (this.t.getTypeKey() == DimensionManager.m && worldserver.getTypeKey() == DimensionManager.k);
    boolean flag1 = (worldserver.getTypeKey() == DimensionManager.m);
    if (!flag && !flag1) {
      boolean flag2 = (worldserver.getTypeKey() == DimensionManager.l);
      if (this.t.getTypeKey() != DimensionManager.l && !flag2)
        return null; 
      WorldBorder worldborder = worldserver.getWorldBorder();
      double d0 = Math.max(-2.9999872E7D, worldborder.e() + 16.0D);
      double d1 = Math.max(-2.9999872E7D, worldborder.f() + 16.0D);
      double d2 = Math.min(2.9999872E7D, worldborder.g() - 16.0D);
      double d3 = Math.min(2.9999872E7D, worldborder.h() - 16.0D);
      double d4 = DimensionManager.a(this.t.getDimensionManager(), worldserver.getDimensionManager());
      BlockPosition blockposition = new BlockPosition(MathHelper.a(locX() * d4, d0, d2), locY(), MathHelper.a(locZ() * d4, d1, d3));
      CraftPortalEvent craftPortalEvent = callPortalEvent(this, worldserver, blockposition, PlayerTeleportEvent.TeleportCause.NETHER_PORTAL, flag2 ? 16 : 128, 16);
      if (craftPortalEvent == null)
        return null; 
      WorldServer worldserverFinal = worldserver = ((CraftWorld)craftPortalEvent.getTo().getWorld()).getHandle();
      blockposition = new BlockPosition(craftPortalEvent.getTo().getX(), craftPortalEvent.getTo().getY(), craftPortalEvent.getTo().getZ());
      return findOrCreatePortal(worldserver, blockposition, flag2, craftPortalEvent.getSearchRadius(), craftPortalEvent.getCanCreatePortal(), craftPortalEvent.getCreationRadius()).<ShapeDetectorShape>map(blockutil_rectangle -> {
            EnumDirection.EnumAxis enumdirection_enumaxis;
            Vec3D vec3d;
            IBlockData iblockdata = this.t.getType(this.ai);
            if (iblockdata.b((IBlockState)BlockProperties.F)) {
              enumdirection_enumaxis = (EnumDirection.EnumAxis)iblockdata.get((IBlockState)BlockProperties.F);
              BlockUtil.Rectangle blockutil_rectangle1 = BlockUtil.a(this.ai, enumdirection_enumaxis, 21, EnumDirection.EnumAxis.b, 21, ());
              vec3d = a(enumdirection_enumaxis, blockutil_rectangle1);
            } else {
              enumdirection_enumaxis = EnumDirection.EnumAxis.a;
              vec3d = new Vec3D(0.5D, 0.0D, 0.0D);
            } 
            return BlockPortalShape.a(paramWorldServer, blockutil_rectangle, enumdirection_enumaxis, vec3d, a(getPose()), getMot(), getYRot(), getXRot(), paramCraftPortalEvent);
          }).orElse(null);
    } 
    if (flag1) {
      blockposition1 = WorldServer.a;
    } else {
      blockposition1 = worldserver.getHighestBlockYAt(HeightMap.Type.f, worldserver.getSpawn());
    } 
    CraftPortalEvent event = callPortalEvent(this, worldserver, blockposition1, PlayerTeleportEvent.TeleportCause.END_PORTAL, 0, 0);
    if (event == null)
      return null; 
    BlockPosition blockposition1 = new BlockPosition(event.getTo().getX(), event.getTo().getY(), event.getTo().getZ());
    return new ShapeDetectorShape(new Vec3D(blockposition1.getX() + 0.5D, blockposition1.getY(), blockposition1.getZ() + 0.5D), getMot(), getYRot(), getXRot(), ((CraftWorld)event.getTo().getWorld()).getHandle(), event);
  }
  
  protected Vec3D a(EnumDirection.EnumAxis enumdirection_enumaxis, BlockUtil.Rectangle blockutil_rectangle) {
    return BlockPortalShape.a(blockutil_rectangle, enumdirection_enumaxis, getPositionVector(), a(getPose()));
  }
  
  protected CraftPortalEvent callPortalEvent(Entity entity, WorldServer exitWorldServer, BlockPosition exitPosition, PlayerTeleportEvent.TeleportCause cause, int searchRadius, int creationRadius) {
    CraftEntity craftEntity = entity.getBukkitEntity();
    Location enter = craftEntity.getLocation();
    Location exit = new Location((World)exitWorldServer.getWorld(), exitPosition.getX(), exitPosition.getY(), exitPosition.getZ());
    EntityPortalEvent event = new EntityPortalEvent((org.bukkit.entity.Entity)craftEntity, enter, exit, searchRadius);
    event.getEntity().getServer().getPluginManager().callEvent((Event)event);
    if (event.isCancelled() || event.getTo() == null || event.getTo().getWorld() == null || !entity.isAlive())
      return null; 
    return new CraftPortalEvent(event);
  }
  
  protected Optional<BlockUtil.Rectangle> findOrCreatePortal(WorldServer worldserver, BlockPosition blockposition, boolean flag, int searchRadius, boolean canCreatePortal, int createRadius) {
    return worldserver.getTravelAgent().findPortal(blockposition, searchRadius);
  }
  
  public boolean canPortal() {
    return true;
  }
  
  public float a(Explosion explosion, IBlockAccess iblockaccess, BlockPosition blockposition, IBlockData iblockdata, Fluid fluid, float f) {
    return f;
  }
  
  public boolean a(Explosion explosion, IBlockAccess iblockaccess, BlockPosition blockposition, IBlockData iblockdata, float f) {
    return true;
  }
  
  public int ce() {
    return 3;
  }
  
  public boolean isIgnoreBlockTrigger() {
    return false;
  }
  
  public void appendEntityCrashDetails(CrashReportSystemDetails crashreportsystemdetails) {
    crashreportsystemdetails.a("Entity Type", () -> {
          MinecraftKey minecraftkey = EntityTypes.getName(getEntityType());
          return minecraftkey + " (" + getClass().getCanonicalName() + ")";
        });
    crashreportsystemdetails.a("Entity ID", Integer.valueOf(this.as));
    crashreportsystemdetails.a("Entity Name", () -> getDisplayName().getString());
    crashreportsystemdetails.a("Entity's Exact location", String.format(Locale.ROOT, "%.2f, %.2f, %.2f", new Object[] { Double.valueOf(locX()), Double.valueOf(locY()), Double.valueOf(locZ()) }));
    crashreportsystemdetails.a("Entity's Block location", CrashReportSystemDetails.a((LevelHeightAccessor)this.t, MathHelper.floor(locX()), MathHelper.floor(locY()), MathHelper.floor(locZ())));
    Vec3D vec3d = getMot();
    crashreportsystemdetails.a("Entity's Momentum", String.format(Locale.ROOT, "%.2f, %.2f, %.2f", new Object[] { Double.valueOf(vec3d.b), Double.valueOf(vec3d.c), Double.valueOf(vec3d.d) }));
    crashreportsystemdetails.a("Entity's Passengers", () -> getPassengers().toString());
    crashreportsystemdetails.a("Entity's Vehicle", () -> String.valueOf(getVehicle()));
  }
  
  public boolean cg() {
    return (isBurning() && !isSpectator());
  }
  
  public void a_(UUID uuid) {
    this.aj = uuid;
    this.ak = this.aj.toString();
  }
  
  public UUID getUniqueID() {
    return this.aj;
  }
  
  public String getUniqueIDString() {
    return this.ak;
  }
  
  public String getName() {
    return this.ak;
  }
  
  public boolean ck() {
    return true;
  }
  
  public static double cl() {
    return aq;
  }
  
  public static void b(double d0) {
    aq = d0;
  }
  
  public IChatBaseComponent getScoreboardDisplayName() {
    return (IChatBaseComponent)ScoreboardTeam.a(getScoreboardTeam(), getDisplayName()).format(chatmodifier -> chatmodifier.setChatHoverable(cq()).setInsertion(getUniqueIDString()));
  }
  
  public void setCustomName(@Nullable IChatBaseComponent ichatbasecomponent) {
    this.Y.set(aJ, Optional.ofNullable(ichatbasecomponent));
  }
  
  @Nullable
  public IChatBaseComponent getCustomName() {
    return ((Optional<IChatBaseComponent>)this.Y.get(aJ)).orElse(null);
  }
  
  public boolean hasCustomName() {
    return ((Optional)this.Y.get(aJ)).isPresent();
  }
  
  public void setCustomNameVisible(boolean flag) {
    this.Y.set(aK, Boolean.valueOf(flag));
  }
  
  public boolean getCustomNameVisible() {
    return ((Boolean)this.Y.get(aK)).booleanValue();
  }
  
  public final void enderTeleportAndLoad(double d0, double d1, double d2) {
    if (this.t instanceof WorldServer) {
      ChunkCoordIntPair chunkcoordintpair = new ChunkCoordIntPair(new BlockPosition(d0, d1, d2));
      ((WorldServer)this.t).getChunkProvider().addTicket(TicketType.g, chunkcoordintpair, 0, Integer.valueOf(getId()));
      this.t.getChunkAt(chunkcoordintpair.b, chunkcoordintpair.c);
      enderTeleportTo(d0, d1, d2);
    } 
  }
  
  public void a(double d0, double d1, double d2) {
    enderTeleportTo(d0, d1, d2);
  }
  
  public void enderTeleportTo(double d0, double d1, double d2) {
    if (this.t instanceof WorldServer) {
      setPositionRotation(d0, d1, d2, getYRot(), getXRot());
      recursiveStream().forEach(entity -> {
            UnmodifiableIterator unmodifiableiterator = entity.at.iterator();
            while (unmodifiableiterator.hasNext()) {
              Entity entity1 = (Entity)unmodifiableiterator.next();
              entity.a(entity1, Entity::teleportAndSync);
            } 
          });
    } 
  }
  
  public boolean cn() {
    return getCustomNameVisible();
  }
  
  public void a(DataWatcherObject<?> datawatcherobject) {
    if (ad.equals(datawatcherobject))
      updateSize(); 
  }
  
  public void updateSize() {
    EntitySize entitysize = this.aW;
    EntityPose entitypose = getPose();
    EntitySize entitysize1 = a(entitypose);
    this.aW = entitysize1;
    this.aX = getHeadHeight(entitypose, entitysize1);
    ah();
    boolean flag = (entitysize1.a <= 4.0D && entitysize1.b <= 4.0D);
    if (!this.t.y && !this.X && !this.P && flag && (entitysize1.a > entitysize.a || entitysize1.b > entitysize.b) && !(this instanceof EntityHuman)) {
      Vec3D vec3d = getPositionVector().add(0.0D, entitysize.b / 2.0D, 0.0D);
      double d0 = Math.max(0.0F, entitysize1.a - entitysize.a) + 1.0E-6D;
      double d1 = Math.max(0.0F, entitysize1.b - entitysize.b) + 1.0E-6D;
      VoxelShape voxelshape = VoxelShapes.a(AxisAlignedBB.a(vec3d, d0, d1, d0));
      this.t.a(this, voxelshape, vec3d, entitysize1.a, entitysize1.b, entitysize1.a).ifPresent(vec3d1 -> b(vec3d1.add(0.0D, -paramEntitySize.b / 2.0D, 0.0D)));
    } 
  }
  
  public EnumDirection getDirection() {
    return EnumDirection.fromAngle(getYRot());
  }
  
  public EnumDirection getAdjustedDirection() {
    return getDirection();
  }
  
  protected ChatHoverable cq() {
    return new ChatHoverable(ChatHoverable.EnumHoverAction.c, new ChatHoverable.b(getEntityType(), getUniqueID(), getDisplayName()));
  }
  
  public boolean a(EntityPlayer entityplayer) {
    return true;
  }
  
  public final AxisAlignedBB getBoundingBox() {
    return this.aA;
  }
  
  public AxisAlignedBB cs() {
    return getBoundingBox();
  }
  
  protected AxisAlignedBB d(EntityPose entitypose) {
    EntitySize entitysize = a(entitypose);
    float f = entitysize.a / 2.0F;
    Vec3D vec3d = new Vec3D(locX() - f, locY(), locZ() - f);
    Vec3D vec3d1 = new Vec3D(locX() + f, locY() + entitysize.b, locZ() + f);
    return new AxisAlignedBB(vec3d, vec3d1);
  }
  
  public final void a(AxisAlignedBB axisalignedbb) {
    double minX = axisalignedbb.a;
    double minY = axisalignedbb.b;
    double minZ = axisalignedbb.c;
    double maxX = axisalignedbb.d;
    double maxY = axisalignedbb.e;
    double maxZ = axisalignedbb.f;
    double len = axisalignedbb.d - axisalignedbb.a;
    if (len < 0.0D)
      maxX = minX; 
    if (len > 64.0D)
      maxX = minX + 64.0D; 
    len = axisalignedbb.e - axisalignedbb.b;
    if (len < 0.0D)
      maxY = minY; 
    if (len > 64.0D)
      maxY = minY + 64.0D; 
    len = axisalignedbb.f - axisalignedbb.c;
    if (len < 0.0D)
      maxZ = minZ; 
    if (len > 64.0D)
      maxZ = minZ + 64.0D; 
    this.aA = new AxisAlignedBB(minX, minY, minZ, maxX, maxY, maxZ);
  }
  
  protected float getHeadHeight(EntityPose entitypose, EntitySize entitysize) {
    return entitysize.b * 0.85F;
  }
  
  public float e(EntityPose entitypose) {
    return getHeadHeight(entitypose, a(entitypose));
  }
  
  public final float getHeadHeight() {
    return this.aX;
  }
  
  public Vec3D cu() {
    return new Vec3D(0.0D, getHeadHeight(), (getWidth() * 0.4F));
  }
  
  public SlotAccess k(int i) {
    return SlotAccess.a;
  }
  
  public void sendMessage(IChatBaseComponent ichatbasecomponent, UUID uuid) {}
  
  public World getWorld() {
    return this.t;
  }
  
  @Nullable
  public MinecraftServer getMinecraftServer() {
    return this.t.getMinecraftServer();
  }
  
  public EnumInteractionResult a(EntityHuman entityhuman, Vec3D vec3d, EnumHand enumhand) {
    return EnumInteractionResult.d;
  }
  
  public boolean cx() {
    return false;
  }
  
  public void a(EntityLiving entityliving, Entity entity) {
    if (entity instanceof EntityLiving)
      EnchantmentManager.a((EntityLiving)entity, entityliving); 
    EnchantmentManager.b(entityliving, entity);
  }
  
  public void c(EntityPlayer entityplayer) {}
  
  public void d(EntityPlayer entityplayer) {}
  
  public float a(EnumBlockRotation enumblockrotation) {
    float f = MathHelper.g(getYRot());
    switch (enumblockrotation) {
      case null:
        return f + 180.0F;
      case d:
        return f + 270.0F;
      case b:
        return f + 90.0F;
    } 
    return f;
  }
  
  public float a(EnumBlockMirror enumblockmirror) {
    float f = MathHelper.g(getYRot());
    switch (enumblockmirror) {
      case b:
        return -f;
      case null:
        return 180.0F - f;
    } 
    return f;
  }
  
  public boolean cy() {
    return false;
  }
  
  @Nullable
  public Entity getRidingPassenger() {
    return null;
  }
  
  public final List<Entity> getPassengers() {
    return (List<Entity>)this.at;
  }
  
  @Nullable
  public Entity cB() {
    return this.at.isEmpty() ? null : (Entity)this.at.get(0);
  }
  
  public boolean u(Entity entity) {
    return this.at.contains(entity);
  }
  
  public boolean a(Predicate<Entity> predicate) {
    Entity entity;
    UnmodifiableIterator unmodifiableiterator = this.at.iterator();
    do {
      if (!unmodifiableiterator.hasNext())
        return false; 
      entity = (Entity)unmodifiableiterator.next();
    } while (!predicate.test(entity));
    return true;
  }
  
  private Stream<Entity> n() {
    return this.at.stream().flatMap(Entity::recursiveStream);
  }
  
  public Stream<Entity> recursiveStream() {
    return Stream.concat(Stream.of(this), n());
  }
  
  public Stream<Entity> cD() {
    return Stream.concat(this.at.stream().flatMap(Entity::cD), Stream.of(this));
  }
  
  public Iterable<Entity> getAllPassengers() {
    return () -> n().iterator();
  }
  
  public boolean hasSinglePlayerPassenger() {
    return (n().filter(entity -> entity instanceof EntityHuman)
      
      .count() == 1L);
  }
  
  public Entity getRootVehicle() {
    for (Entity entity = this; entity.isPassenger(); entity = entity.getVehicle());
    return entity;
  }
  
  public boolean isSameVehicle(Entity entity) {
    return (getRootVehicle() == entity.getRootVehicle());
  }
  
  public boolean w(Entity entity) {
    return n().anyMatch(entity1 -> (entity1 == paramEntity1));
  }
  
  public boolean cH() {
    Entity entity = getRidingPassenger();
    return (entity instanceof EntityHuman) ? ((EntityHuman)entity).fi() : (!this.t.y);
  }
  
  protected static Vec3D a(double d0, double d1, float f) {
    double d2 = (d0 + d1 + 9.999999747378752E-6D) / 2.0D;
    float f1 = -MathHelper.sin(f * 0.017453292F);
    float f2 = MathHelper.cos(f * 0.017453292F);
    float f3 = Math.max(Math.abs(f1), Math.abs(f2));
    return new Vec3D(f1 * d2 / f3, 0.0D, f2 * d2 / f3);
  }
  
  public Vec3D b(EntityLiving entityliving) {
    return new Vec3D(locX(), (getBoundingBox()).e, locZ());
  }
  
  @Nullable
  public Entity getVehicle() {
    return this.au;
  }
  
  public EnumPistonReaction getPushReaction() {
    return EnumPistonReaction.a;
  }
  
  public SoundCategory getSoundCategory() {
    return SoundCategory.g;
  }
  
  public int getMaxFireTicks() {
    return 1;
  }
  
  public CommandListenerWrapper getCommandListener() {
    return new CommandListenerWrapper(this, getPositionVector(), br(), (this.t instanceof WorldServer) ? (WorldServer)this.t : null, y(), getDisplayName().getString(), getScoreboardDisplayName(), this.t.getMinecraftServer(), this);
  }
  
  protected int y() {
    return 0;
  }
  
  public boolean l(int i) {
    return (y() >= i);
  }
  
  public boolean shouldSendSuccess() {
    return this.t.getGameRules().getBoolean(GameRules.o);
  }
  
  public boolean shouldSendFailure() {
    return true;
  }
  
  public boolean shouldBroadcastCommands() {
    return true;
  }
  
  public void a(ArgumentAnchor.Anchor argumentanchor_anchor, Vec3D vec3d) {
    Vec3D vec3d1 = argumentanchor_anchor.a(this);
    double d0 = vec3d.b - vec3d1.b;
    double d1 = vec3d.c - vec3d1.c;
    double d2 = vec3d.d - vec3d1.d;
    double d3 = Math.sqrt(d0 * d0 + d2 * d2);
    setXRot(MathHelper.g((float)-(MathHelper.d(d1, d3) * 57.2957763671875D)));
    setYRot(MathHelper.g((float)(MathHelper.d(d2, d0) * 57.2957763671875D) - 90.0F));
    setHeadRotation(getYRot());
    this.y = getXRot();
    this.x = getYRot();
  }
  
  public boolean a(Tag<FluidType> tag, double d0) {
    if (cM())
      return false; 
    AxisAlignedBB axisalignedbb = getBoundingBox().shrink(0.001D);
    int i = MathHelper.floor(axisalignedbb.a);
    int j = MathHelper.e(axisalignedbb.d);
    int k = MathHelper.floor(axisalignedbb.b);
    int l = MathHelper.e(axisalignedbb.e);
    int i1 = MathHelper.floor(axisalignedbb.c);
    int j1 = MathHelper.e(axisalignedbb.f);
    double d1 = 0.0D;
    boolean flag = ck();
    boolean flag1 = false;
    Vec3D vec3d = Vec3D.a;
    int k1 = 0;
    BlockPosition.MutableBlockPosition blockposition_mutableblockposition = new BlockPosition.MutableBlockPosition();
    for (int l1 = i; l1 < j; l1++) {
      for (int i2 = k; i2 < l; i2++) {
        for (int j2 = i1; j2 < j1; j2++) {
          blockposition_mutableblockposition.d(l1, i2, j2);
          Fluid fluid = this.t.getFluid((BlockPosition)blockposition_mutableblockposition);
          if (fluid.a(tag)) {
            double d2 = (i2 + fluid.getHeight((IBlockAccess)this.t, (BlockPosition)blockposition_mutableblockposition));
            if (d2 >= axisalignedbb.b) {
              flag1 = true;
              d1 = Math.max(d2 - axisalignedbb.b, d1);
              if (flag) {
                Vec3D vec3d1 = fluid.c((IBlockAccess)this.t, (BlockPosition)blockposition_mutableblockposition);
                if (d1 < 0.4D)
                  vec3d1 = vec3d1.a(d1); 
                vec3d = vec3d.e(vec3d1);
                k1++;
              } 
            } 
          } 
        } 
      } 
    } 
    if (vec3d.f() > 0.0D) {
      if (k1 > 0)
        vec3d = vec3d.a(1.0D / k1); 
      if (!(this instanceof EntityHuman))
        vec3d = vec3d.d(); 
      Vec3D vec3d2 = getMot();
      vec3d = vec3d.a(d0 * 1.0D);
      double d3 = 0.003D;
      if (Math.abs(vec3d2.b) < 0.003D && Math.abs(vec3d2.d) < 0.003D && vec3d.f() < 0.0045000000000000005D)
        vec3d = vec3d.d().a(0.0045000000000000005D); 
      setMot(getMot().e(vec3d));
    } 
    this.T.put(tag, d1);
    return flag1;
  }
  
  public boolean cM() {
    AxisAlignedBB axisalignedbb = getBoundingBox().g(1.0D);
    int i = MathHelper.floor(axisalignedbb.a);
    int j = MathHelper.e(axisalignedbb.d);
    int k = MathHelper.floor(axisalignedbb.c);
    int l = MathHelper.e(axisalignedbb.f);
    return !this.t.b(i, k, j, l);
  }
  
  public double b(Tag<FluidType> tag) {
    return this.T.getDouble(tag);
  }
  
  public double cN() {
    return (getHeadHeight() < 0.4D) ? 0.0D : 0.4D;
  }
  
  public final float getWidth() {
    return this.aW.a;
  }
  
  public final float getHeight() {
    return this.aW.b;
  }
  
  public EntitySize a(EntityPose entitypose) {
    return this.ar.m();
  }
  
  public Vec3D getPositionVector() {
    return this.av;
  }
  
  public BlockPosition getChunkCoordinates() {
    return this.aw;
  }
  
  public IBlockData cS() {
    return this.t.getType(getChunkCoordinates());
  }
  
  public BlockPosition cT() {
    return new BlockPosition(i(1.0F));
  }
  
  public ChunkCoordIntPair cU() {
    return new ChunkCoordIntPair(this.aw);
  }
  
  public Vec3D getMot() {
    return this.ax;
  }
  
  public void setMot(Vec3D vec3d) {
    this.ax = vec3d;
  }
  
  public void setMot(double d0, double d1, double d2) {
    setMot(new Vec3D(d0, d1, d2));
  }
  
  public final int cW() {
    return this.aw.getX();
  }
  
  public final double locX() {
    return this.av.b;
  }
  
  public double c(double d0) {
    return this.av.b + getWidth() * d0;
  }
  
  public double d(double d0) {
    return c((2.0D * this.Q.nextDouble() - 1.0D) * d0);
  }
  
  public final int cY() {
    return this.aw.getY();
  }
  
  public final double locY() {
    return this.av.c;
  }
  
  public double e(double d0) {
    return this.av.c + getHeight() * d0;
  }
  
  public double da() {
    return e(this.Q.nextDouble());
  }
  
  public double getHeadY() {
    return this.av.c + this.aX;
  }
  
  public final int dc() {
    return this.aw.getZ();
  }
  
  public final double locZ() {
    return this.av.d;
  }
  
  public double f(double d0) {
    return this.av.d + getWidth() * d0;
  }
  
  public double g(double d0) {
    return f((2.0D * this.Q.nextDouble() - 1.0D) * d0);
  }
  
  public final void setPositionRaw(double d0, double d1, double d2) {
    if (this.av.b != d0 || this.av.c != d1 || this.av.d != d2) {
      this.av = new Vec3D(d0, d1, d2);
      int i = MathHelper.floor(d0);
      int j = MathHelper.floor(d1);
      int k = MathHelper.floor(d2);
      if (i != this.aw.getX() || j != this.aw.getY() || k != this.aw.getZ())
        this.aw = new BlockPosition(i, j, k); 
      this.aO.a();
      GameEventListenerRegistrar gameeventlistenerregistrar = bQ();
      if (gameeventlistenerregistrar != null)
        gameeventlistenerregistrar.b(this.t); 
    } 
  }
  
  public void checkDespawn() {}
  
  public Vec3D n(float f) {
    return k(f).add(0.0D, this.aX * 0.7D, 0.0D);
  }
  
  public void a(PacketPlayOutSpawnEntity packetplayoutspawnentity) {
    int i = packetplayoutspawnentity.b();
    double d0 = packetplayoutspawnentity.d();
    double d1 = packetplayoutspawnentity.e();
    double d2 = packetplayoutspawnentity.f();
    d(d0, d1, d2);
    teleportAndSync(d0, d1, d2);
    setXRot((packetplayoutspawnentity.j() * 360) / 256.0F);
    setYRot((packetplayoutspawnentity.k() * 360) / 256.0F);
    e(i);
    a_(packetplayoutspawnentity.c());
  }
  
  @Nullable
  public ItemStack df() {
    return null;
  }
  
  public void o(boolean flag) {
    this.al = flag;
  }
  
  public boolean dg() {
    return !TagsEntity.j.isTagged(getEntityType());
  }
  
  public float getYRot() {
    return this.ay;
  }
  
  public void setYRot(float f) {
    if (!Float.isFinite(f)) {
      SystemUtils.a("Invalid entity rotation: " + f + ", discarding.");
    } else {
      this.ay = f;
    } 
  }
  
  public float getXRot() {
    return this.az;
  }
  
  public void setXRot(float f) {
    if (!Float.isFinite(f)) {
      SystemUtils.a("Invalid entity rotation: " + f + ", discarding.");
    } else {
      this.az = f;
    } 
  }
  
  public final boolean isRemoved() {
    return (this.aB != null);
  }
  
  @Nullable
  public RemovalReason getRemovalReason() {
    return this.aB;
  }
  
  public final void setRemoved(RemovalReason entity_removalreason) {
    if (this.aB == null)
      this.aB = entity_removalreason; 
    if (this.aB.a())
      stopRiding(); 
    getPassengers().forEach(Entity::stopRiding);
    this.aO.a(entity_removalreason);
  }
  
  public void unsetRemoved() {
    this.aB = null;
  }
  
  public void a(EntityInLevelCallback entityinlevelcallback) {
    this.aO = entityinlevelcallback;
  }
  
  public boolean dm() {
    return (this.aB != null && !this.aB.b()) ? false : (isPassenger() ? false : (!(isVehicle() && hasSinglePlayerPassenger())));
  }
  
  public boolean dn() {
    return false;
  }
  
  public boolean a(World world, BlockPosition blockposition) {
    return true;
  }
  
  protected abstract void initDatawatcher();
  
  protected abstract void loadData(NBTTagCompound paramNBTTagCompound);
  
  protected abstract void saveData(NBTTagCompound paramNBTTagCompound);
  
  public abstract Packet<?> getPacket();
  
  public enum RemovalReason {
    a(true, false),
    b(true, false),
    c(false, true),
    d(false, false),
    e(false, false);
    
    private final boolean g;
    
    private final boolean f;
    
    RemovalReason(boolean flag, boolean flag1) {
      this.f = flag;
      this.g = flag1;
    }
    
    public boolean a() {
      return this.f;
    }
    
    public boolean b() {
      return this.g;
    }
  }
  
  public enum MovementEmission {
    a(false, false),
    b(true, false),
    c(false, true),
    d(true, true);
    
    final boolean f;
    
    final boolean e;
    
    MovementEmission(boolean flag, boolean flag1) {
      this.e = flag;
      this.f = flag1;
    }
    
    public boolean a() {
      return !(!this.f && !this.e);
    }
    
    public boolean b() {
      return this.f;
    }
    
    public boolean c() {
      return this.e;
    }
  }
  
  @FunctionalInterface
  public static interface MoveFunction {
    void accept(Entity param1Entity, double param1Double1, double param1Double2, double param1Double3);
  }
}
