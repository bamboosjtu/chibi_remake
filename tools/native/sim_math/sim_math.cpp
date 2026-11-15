// Deterministic math and collision queries. No scene nodes, path planning, RNG,
// damage resolution, or retained world objects.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <godot_cpp/classes/a_star2d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector4i.hpp>
#include <unordered_map>
#include <vector>
using namespace godot;
// Query objects belong to one navigation revision, never to the provider.
class ChibiNavigationQuery : public RefCounted {
    GDCLASS(ChibiNavigationQuery, RefCounted)
  protected:
    static void _bind_methods() {}

  public:
    struct Contact {
        double ax, ay, bx, by, range;
        int64_t target, attacker_type, target_type;
        bool clear;
    };
    bool ready = false;
    double w = 0, tw = 0, th = 0;
    int rows = 0, cols = 0;
    int64_t version = 0;
    Ref<AStar2D> land, water;
    Dictionary occupancy;
    std::unordered_map<int64_t, Contact> contacts;
};
// A named command port, connected once by the domain composition root.
// Each command delegates to the existing guarded GDScript dependency port.
class ChibiUnitCommands : public RefCounted {
    GDCLASS(ChibiUnitCommands, RefCounted)
  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("release_commands"), &ChibiUnitCommands::release_commands);
    }

  public:
    Callable fire, repath, walk, yield, fallback, die, navigation, abort;
    Array noargs;
    bool valid() const {
        return fire.is_valid() && repath.is_valid() && walk.is_valid() && yield.is_valid() &&
               fallback.is_valid() && die.is_valid() && navigation.is_valid() && abort.is_valid();
    }
    void release_commands() {
        fire = Callable();
        repath = Callable();
        walk = Callable();
        yield = Callable();
        fallback = Callable();
        die = Callable();
        navigation = Callable();
    }
    void fire_attack(Dictionary u, Dictionary target) { fire.callv(Array::make(u, target)); }
    void repath_attack(Dictionary u, Dictionary target, double range) {
        repath.callv(Array::make(u, target, range));
    }
    void follow(Dictionary u, double delta) { walk.callv(Array::make(u, delta)); }
    void separate(Dictionary u) { yield.callv(Array::make(u)); }
    void step_unit(Dictionary u, double delta) { fallback.callv(Array::make(u, delta)); }
    void die_step(Dictionary u, double delta) { die.callv(Array::make(u, delta)); }
    Dictionary navigation_context() { return navigation.callv(noargs); }
    void refresh_context(Dictionary &context) {
        // The pinned bindings' Dictionary rvalue assignment overwrites storage
        // without releasing its old reference. Use the verified copy operator.
        const Dictionary next = navigation_context();
        context = next;
    }
};
class ChibiSimulationMath : public RefCounted {
    GDCLASS(ChibiSimulationMath, RefCounted)
    struct Keys {
        Variant rate{"rate"}, haste{"haste_t"}, slow{"slow_t"}, wait{"action_wait"},
            phase{"action_phase"}, started{"action_started"}, kind{"action_kind"},
            target{"action_target_uid"}, clips{"clips"}, dir{"dir"};
        Variant building{"is_building"}, walk{"walk_tick"}, facing{"move_facing"},
            turn{"turn_tick"}, moved_started{"move_started"}, turning{"move_turning"},
            attached{"attached"}, site{"site_inside_uid"}, task{"effect_task"}, moved{"moved"},
            state{"state"}, pending{"effect_tasks"}, confused{"confused_t"}, rolling{"rolling_t"},
            ax{"ax"}, ay{"ay"}, uid{"uid"};
        Variant unit{"unit"}, anim{"anim"}, die_t{"die_t"}, owner{"owner"}, vision{"vision"},
            farsight_t{"farsight_t"}, site_flag{"site"}, position{"position"},
            source_cells{"cells"};
        Variant alive{"alive"};
        Variant burn_t{"burn_t"};
        Variant site_follow_uid{"site_follow_uid"};
        Variant ambush_t{"ambush_t"};
        Variant atk_range{"atk_range"};
        Variant attack{"attack"};
        Variant attack_b{"attack_b"};
        Variant target_record{"target"};
        Variant route_failures{"route_failures"};
        Variant path{"path"};
        Variant pi{"pi"};
        Variant repath{"repath"};
        Variant rolling_ticks{"rolling_ticks"};
        Variant occupied_cells{"occupied_cells"};
        Variant decor{"decor"};
        Variant w{"w"};
        Variant rows{"rows"};
        Variant cols{"cols"};
        Variant terrainW{"terrainW"};
        Variant terrainH{"terrainH"};
        Variant context_version{"version"};
        Variant land{"land"};
        Variant water{"water"};
        Variant hasWater{"hasWater"};
        Variant occupancy{"occupancy"}, native_query{"nativeQuery"};
    } k;
    std::unordered_map<int64_t, int> classes;
    std::vector<Vector2i> shapes[4][2];
    std::vector<int64_t> naval;
    static ChibiNavigationQuery *query(const Dictionary &c, const Variant &key) {
        Variant raw = c.get(key, Variant());
        auto q = raw.get_type() == Variant::OBJECT
                     ? Object::cast_to<ChibiNavigationQuery>(static_cast<Object *>(raw))
                     : nullptr;
        return q && q->ready ? q : nullptr;
    }
    struct Geometry {
        double w, hw, hh, tw, th;
        int rows, cols;
        int64_t version;
        AStar2D *graph;
        Dictionary occupancy;
        Geometry(const Dictionary &c, bool water, const Keys &k)
            : Geometry(c, water, k, query(c, k.native_query)) {}
        Geometry(const Dictionary &c, bool water, const Keys &k, ChibiNavigationQuery *q)
            : w(q ? q->w : double(c[k.w])), hw(w * .5), hh(w * .25),
              tw(q ? q->tw : double(c[k.terrainW])), th(q ? q->th : double(c[k.terrainH])),
              rows(q ? q->rows : int64_t(c[k.rows])), cols(q ? q->cols : int64_t(c[k.cols])),
              version(q ? q->version : int64_t(c[k.context_version])),
              occupancy(q ? q->occupancy : Dictionary(c[k.occupancy])) {
            graph =
                q ? (water ? q->water.ptr() : q->land.ptr())
                  : Object::cast_to<AStar2D>(static_cast<Object *>(c[water ? k.water : k.land]));
        }
        Vector2i cell(double x, double y) const {
            int b = int(std::round((y - hw) / hh));
            int a = int(std::round((x - hw - hw * (b & 1)) / w));
            return Vector2i(std::clamp(a, 0, rows - 1), std::clamp(b, 0, cols - 1));
        }
        bool inside(Vector2i c) const { return c.x >= 0 && c.y >= 0 && c.x < rows && c.y < cols; }
        bool solid(Vector2i c) const {
            if (!inside(c))
                return true;
            int64_t id = int64_t(c.x) * cols + c.y;
            return graph->is_point_disabled(id) || int64_t(occupancy.get(id, 0)) > 0;
        }
        Vector2 anchor(Vector2i c) const {
            return Vector2(w * c.x + hw * (c.y & 1) + hw, hh * c.y + hw);
        }
    };
    int shape_class(int64_t uid) const {
        auto it = classes.find(uid);
        return it == classes.end() ? 0 : it->second;
    }
    bool water_layer(const Dictionary &u, const Dictionary &context) {
        return bool(context[k.hasWater]) &&
               std::find(naval.begin(), naval.end(), integer(u, k.unit, -1)) != naval.end();
    }
    template <class F> bool ray(Vector2 a, Vector2 b, const Geometry &g, F visit) {
        int lo = int(std::round((std::min(double(a.y), double(b.y)) - g.hw) / g.hh)),
            hi = int(std::round((std::max(double(a.y), double(b.y)) - g.hw) / g.hh));
        double dy = double(b.y) - double(a.y);
        for (int row = lo; row <= hi; ++row) {
            double start = 0, end = 1;
            if (std::abs(dy) > 0.000001) {
                double t0 = (g.hw + (row - .5) * g.hh - a.y) / dy,
                       t1 = (g.hw + (row + .5) * g.hh - a.y) / dy;
                start = std::max(0.0, std::min(t0, t1));
                end = std::min(1.0, std::max(t0, t1));
                if (start > end)
                    continue;
            }
            double x0 = a.x + (double(b.x) - a.x) * start, x1 = a.x + (double(b.x) - a.x) * end,
                   offset = g.hw + g.hw * (row & 1);
            int first = std::clamp(int(std::floor((std::min(x0, x1) - offset) / g.w + .5)), 0,
                                   g.rows - 1),
                last = std::clamp(int(std::floor((std::max(x0, x1) - offset) / g.w + .5)), 0,
                                  g.rows - 1);
            for (int col = first; col <= last; ++col)
                if (!visit(Vector2i(col, std::clamp(row, 0, g.cols - 1))))
                    return false;
        }
        return true;
    }
    std::vector<Vector2i> foot(const Dictionary &u, const Geometry &g) {
        Variant raw = u.get(k.occupied_cells, Variant());
        if (raw.get_type() == Variant::ARRAY && !Array(raw).is_empty()) {
            std::vector<Vector2i> result;
            Array a = raw;
            result.reserve(a.size());
            for (int64_t i = 0; i < a.size(); ++i)
                result.push_back(Vector2i(a[i]));
            return result;
        }
        Vector2i anchor = g.cell(double(u[k.ax]), double(u[k.ay]));
        if (boolean(u, k.decor))
            return {anchor};
        int cls = shape_class(integer(u, k.unit, -1));
        std::vector<Vector2i> result;
        result.reserve(shapes[cls][anchor.y & 1].size());
        for (auto off : shapes[cls][anchor.y & 1]) {
            auto cell = anchor + off;
            if (boolean(u, k.building) && !g.inside(cell))
                return {anchor};
            result.push_back(cell);
        }
        return result;
    }
    bool line_contact(const Dictionary &u, const Dictionary &t, const Geometry &g) {
        auto ignore = foot(u, g);
        auto other = foot(t, g);
        ignore.insert(ignore.end(), other.begin(), other.end());
        return ray(Vector2(double(u[k.ax]), double(u[k.ay])),
                   Vector2(double(t[k.ax]), double(t[k.ay])), g, [&](Vector2i c) {
                       return std::find(ignore.begin(), ignore.end(), c) != ignore.end() ||
                              !g.solid(c);
                   });
    }
    bool body_clear(Vector2 a, Vector2 b, const Geometry &g, int cls) {
        if (b.x < 0 || b.y < 0 || b.x >= g.tw || b.y >= g.th)
            return false;
        auto start = g.cell(a.x, a.y);
        std::vector<Vector2i> allowed;
        for (auto off : shapes[cls][start.y & 1])
            allowed.push_back(start + off);
        return ray(a, b, g, [&](Vector2i anchor) {
            for (auto off : shapes[cls][anchor.y & 1]) {
                auto c = anchor + off;
                if (std::find(allowed.begin(), allowed.end(), c) == allowed.end() && g.solid(c))
                    return false;
            }
            return true;
        });
    }
    bool placement(Vector2i c, int cls, int64_t uid, const Geometry &g, const Dictionary &table) {
        for (auto off : shapes[cls][c.y & 1]) {
            auto p = c + off;
            if (g.solid(p))
                return false;
            Variant raw = table.get(p, Variant());
            if (raw.get_type() == Variant::DICTIONARY) {
                Dictionary b = raw;
                if (b.size() > 1 || !b.has(uid))
                    return false;
            }
        }
        return true;
    }
    const String attack_state{"attack"}, idle_state{"idle"}, repair_state{"repair"};
    std::vector<Variant> statuses;
    Variant clip;
    int64_t frame_ticks = 2, confusion = 27, rolling = 28;
    static int64_t integer(const Dictionary &u, const Variant &key, int64_t fallback = 0) {
        return int64_t(u.get(key, fallback));
    }
    static bool boolean(const Dictionary &u, const Variant &key) { return bool(u.get(key, false)); }
    bool active(const Dictionary &u) {
        auto t = integer(u, k.task);
        return t == confusion || t == rolling;
    }
    bool task_alive(const Dictionary &u, int64_t t) {
        return integer(u, t == confusion ? k.confused : k.rolling) > 0;
    }
    void reset(Dictionary &u) {
        u[k.wait] = int64_t(0);
        u[k.phase] = int64_t(0);
        u[k.started] = false;
        u[k.kind] = String("");
        u[k.target] = int64_t(-1);
    }
    void ensure(Dictionary &u) {
        if (!u.has(k.walk))
            u[k.walk] = int64_t(0);
        if (!u.has(k.facing))
            u[k.facing] = integer(u, k.dir) & 7;
        if (!u.has(k.turn))
            u[k.turn] = int64_t(0);
        if (!u.has(k.moved_started))
            u[k.moved_started] = false;
        if (!u.has(k.turning))
            u[k.turning] = false;
    }

  public:
    String fingerprint() const { return SIM_MATH_SIGNATURE; }
    Ref<ChibiUnitCommands> make_unit_port(const Callable &fire, const Callable &repath,
                                          const Callable &walk, const Callable &yield,
                                          const Callable &fallback, const Callable &die,
                                          const Callable &navigation, const Callable &abort) {
        Ref<ChibiUnitCommands> port;
        port.instantiate();
        port->fire = fire;
        port->repath = repath;
        port->walk = walk;
        port->yield = yield;
        port->fallback = fallback;
        port->die = die;
        port->navigation = navigation;
        port->abort = abort;
        if (!port->valid()) {
            if (abort.is_valid())
                abort.callv(Array());
            return Ref<ChibiUnitCommands>();
        }
        return port;
    }
    Dictionary step_units(const Array &units, double delta, Dictionary context,
                          const Dictionary &owners, const Dictionary &targets,
                          const Dictionary &cells, const Array &indexed, int64_t indexed_size,
                          const Ref<ChibiUnitCommands> &port, bool profile) {
        Dictionary report;
        if (port.is_null() || !port->valid()) {
            if (port.is_valid() && port->abort.is_valid())
                port->abort.callv(Array());
            else
                UtilityFunctions::push_error("Expired native unit command port");
            return report;
        }
        using Clock = std::chrono::steady_clock;
        int64_t prepare = 0, apply = 0, finalize = 0, count = 0;
        auto elapsed = [](Clock::time_point at) {
            return std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now() - at).count();
        };
        // Array size is observed on every iteration, matching GDScript iteration.
        // A structural edit invalidates the fast path and uses guarded script commands.
        for (int64_t i = 0; i < units.size(); ++i) {
            Dictionary u = units[i];
            if (!boolean(u, k.alive))
                continue;
            if (double(u.get(k.die_t, -1.0)) >= 0) {
                port->die_step(u, delta);
                port->refresh_context(context);
                continue;
            }
            auto type = integer(u, k.unit);
            if (boolean(u, k.building) && type != 18 && type != 19)
                continue;
            auto at = profile ? Clock::now() : Clock::time_point();
            auto result =
                attack_fast(u, delta, context, owners, targets, units, indexed, indexed_size);
            if (profile)
                prepare += elapsed(at);
            if (result < 0) {
                port->step_unit(u, delta);
                port->refresh_context(context);
                continue;
            }
            if (profile) {
                ++count;
                at = Clock::now();
            }
            if (result & 1) {
                port->fire_attack(u, u[k.target_record]);
                port->refresh_context(context);
            }
            if (result & 2) {
                port->repath_attack(u, u[k.target_record], double(u[k.atk_range]));
                port->refresh_context(context);
            }
            if (result & 4) {
                port->follow(u, delta);
                port->refresh_context(context);
            }
            u[k.anim] = double(u[k.anim]) + delta;
            if (profile) {
                apply += elapsed(at);
                at = Clock::now();
            }
            if (finish_or_separate(u, cells, context)) {
                port->separate(u);
                finish_plain_attack(u);
                port->refresh_context(context);
            }
            if (profile)
                finalize += elapsed(at);
        }
        if (profile) {
            report["nativePrepare"] = prepare / 1000;
            report["nativeApply"] = apply / 1000;
            report["nativeFinalize"] = finalize / 1000;
            report["nativeAttack"] = (prepare + apply + finalize) / 1000;
            report["units"] = count;
        }
        return report;
    }

    Ref<ChibiNavigationQuery> make_query(const Dictionary &c) {
        Ref<ChibiNavigationQuery> q;
        q.instantiate();
        q->w = double(c[k.w]);
        q->tw = double(c[k.terrainW]);
        q->th = double(c[k.terrainH]);
        q->rows = int64_t(c[k.rows]);
        q->cols = int64_t(c[k.cols]);
        q->version = int64_t(c[k.context_version]);
        q->land = Ref<AStar2D>(Object::cast_to<AStar2D>(static_cast<Object *>(c[k.land])));
        q->water = Ref<AStar2D>(Object::cast_to<AStar2D>(static_cast<Object *>(c[k.water])));
        const Dictionary occupied = c[k.occupancy];
        q->occupancy = occupied;
        q->ready = true;
        return q;
    }

    // Arrays are copied once per visibility update, never once per source.
    // No visibility/world reference is retained by this provider.
    Array update_visibility(const Array &units, int64_t player, int64_t width, int64_t height,
                            const Vector2 &cell, PackedByteArray current, PackedByteArray explored,
                            PackedInt32Array reveals, Dictionary sources, bool full_reveal,
                            double farsight_cells) {
        Dictionary active;
        bool changed = false;
        uint8_t *now = current.ptrw(), *memory = explored.ptrw();
        int32_t *counts = reveals.ptrw();
        auto reveal = [&](const PackedInt32Array &cells, int change) {
            for (int64_t i = 0; i < cells.size(); ++i) {
                auto index = cells[i];
                counts[index] += change;
                uint8_t visible = counts[index] > 0 ? 1 : 0;
                if (now[index] != visible)
                    changed = true;
                now[index] = full_reveal ? 1 : visible;
                if (visible == 1 && memory[index] == 0) {
                    memory[index] = 1;
                    changed = true;
                }
            }
        };
        for (int64_t i = 0; i < units.size(); ++i) {
            Dictionary u = units[i];
            if (!boolean(u, k.alive) || double(u.get(k.die_t, -1.0)) >= 0 ||
                integer(u, "owner") != player || boolean(u, k.attached) ||
                (boolean(u, k.building) && boolean(u, "site")))
                continue;
            String key = u.has(k.uid) ? String("u") + String::num_int64(integer(u, k.uid))
                                      : String("i") + String::num_int64(i);
            active[key] = true;
            Vector2 position(std::floor(double(u[k.ax]) / 11) * 11,
                             std::floor(double(u[k.ay]) / 5.5) * 5.5);
            double vision = integer(u, "farsight_t") > 0
                                ? farsight_cells
                                : std::max(0.0, double(u.get(k.vision, 0.0)));
            Variant raw_old = sources.get(key, Variant());
            Dictionary old =
                raw_old.get_type() == Variant::DICTIONARY ? Dictionary(raw_old) : Dictionary();
            if (!old.is_empty() && Vector2(old[k.position]) == position &&
                double(old[k.vision]) == vision)
                continue;
            PackedInt32Array cells;
            double radius = (vision + 0.5) * 2;
            Vector2 centre = position / cell;
            for (int y = std::max(0, int(std::floor(centre.y - radius)));
                 y < std::min(int(height), int(std::ceil(centre.y + radius)) + 1); ++y)
                for (int x = std::max(0, int(std::floor(centre.x - radius)));
                     x < std::min(int(width), int(std::ceil(centre.x + radius)) + 1); ++x)
                    if (std::abs(x + 0.5 - centre.x) + std::abs(y + 0.5 - centre.y) <= radius)
                        cells.push_back(y * width + x);
            PackedInt32Array before = old.get(k.source_cells, PackedInt32Array()), removed, added;
            int64_t a = 0, b = 0;
            while (a < before.size() && b < cells.size()) {
                if (before[a] == cells[b]) {
                    ++a;
                    ++b;
                } else if (before[a] < cells[b])
                    removed.push_back(before[a++]);
                else
                    added.push_back(cells[b++]);
            }
            while (a < before.size())
                removed.push_back(before[a++]);
            while (b < cells.size())
                added.push_back(cells[b++]);
            reveal(removed, -1);
            reveal(added, 1);
            Dictionary next;
            next[k.position] = position;
            next[k.vision] = vision;
            next[k.source_cells] = cells;
            sources[key] = next;
        }
        Array keys = sources.keys();
        for (int64_t i = 0; i < keys.size(); ++i)
            if (!active.has(keys[i])) {
                Dictionary old = sources[keys[i]];
                reveal(old[k.source_cells], -1);
                sources.erase(keys[i]);
            }
        Array result;
        result.push_back(changed);
        result.push_back(current);
        result.push_back(explored);
        result.push_back(reveals);
        return result;
    }

    void configure(const Array &fields, const StringName &row, int64_t ticks, int64_t confused_task,
                   int64_t rolling_task, const Dictionary &types, const Array &offsets,
                   const Array &naval_types) {
        statuses.clear();
        for (int64_t i = 0; i < fields.size(); ++i)
            statuses.emplace_back(String(fields[i]));
        clip = String(row);
        frame_ticks = ticks;
        confusion = confused_task;
        rolling = rolling_task;
        Array ids = types.keys();
        for (int64_t i = 0; i < ids.size(); ++i)
            classes[int64_t(ids[i])] = int64_t(types[ids[i]]);
        for (int cls = 0; cls < 4; ++cls)
            for (int parity = 0; parity < 2; ++parity) {
                Array a = Array(offsets[cls * 2 + parity]);
                for (int64_t i = 0; i < a.size(); ++i)
                    shapes[cls][parity].push_back(Vector2i(a[i]));
            }
        for (int64_t i = 0; i < naval_types.size(); ++i)
            naval.push_back(int64_t(naval_types[i]));
    }
    bool step_clock(Dictionary u, const String &kind, int64_t target, bool building) {
        if (String(u.get(k.kind, "")) != kind || integer(u, k.target, -1) != target) {
            reset(u);
            u[k.kind] = kind;
            u[k.target] = target;
        }
        if (!boolean(u, k.started)) {
            u[k.started] = true;
            u[k.wait] = int64_t(1);
            return false;
        }
        int64_t rate = std::max<int64_t>(1, integer(u, k.rate, 100));
        if (integer(u, k.haste) > 0)
            rate *= 2;
        else if (integer(u, k.slow) > 0)
            rate = std::max<int64_t>(1, rate / 2);
        int64_t period = std::max<int64_t>(1, 1000 / rate);
        auto wait = std::min(period, integer(u, k.wait) + 1);
        u[k.wait] = wait;
        if (wait < period)
            return false;
        if (!building) {
            Variant raw = u.get(k.clips, Variant());
            if (raw.get_type() != Variant::DICTIONARY)
                return false;
            Dictionary clips = raw;
            raw = clips.get(clip, Variant());
            if (raw.get_type() != Variant::ARRAY)
                return false;
            Array rows = raw;
            if (rows.is_empty())
                return false;
            Array frames = rows[(integer(u, k.dir) & 7) % rows.size()];
            int64_t length = frames.size();
            if (length == 0)
                return false;
            auto phase = (integer(u, k.phase) + 1) % length;
            u[k.phase] = phase;
            if (phase != 2)
                return false;
        }
        u[k.wait] = int64_t(0);
        return true;
    }
    int64_t prepare_attack(Dictionary u, const Dictionary &t, double range, double width,
                           bool tower) {
        Vector2 offset(double(t[k.ax]) - double(u[k.ax]), double(t[k.ay]) - double(u[k.ay]));
        u[k.dir] = int64_t(std::round(double(offset.angle()) /
                                      (3.1415926535897932384626433832795 / 4.0))) &
                   7;
        bool strike = step_clock(u, attack_state, integer(t, k.uid), tower);
        double reach = range * width;
        return (strike ? 1 : 0) | (double(offset.length_squared()) <= reach * reach ? 2 : 0);
    }
    int64_t prepare_combat(Dictionary u, const Dictionary &t, double range, double width,
                           bool tower, const Dictionary &context) {
        int64_t flags = prepare_attack(u, t, range, width, tower);
        bool reach = (flags & 2) != 0;
        if (range <= 1) {
            auto q = query(context, k.native_query);
            auto uid = integer(u, k.uid, -1);
            double ax = double(u[k.ax]), ay = double(u[k.ay]), bx = double(t[k.ax]),
                   by = double(t[k.ay]);
            auto target = integer(t, k.uid), atype = integer(u, k.unit), btype = integer(t, k.unit);
            if (q) {
                auto found = q->contacts.find(uid);
                if (found != q->contacts.end()) {
                    const auto &row = found->second;
                    if (row.ax == ax && row.ay == ay && row.bx == bx && row.by == by &&
                        row.target == target && row.attacker_type == atype &&
                        row.target_type == btype && row.range == range)
                        return (flags & 1) | (row.clear ? 2 : 0);
                }
            }
            Geometry g(context, water_layer(u, context), k, q);
            if (!reach) {
                auto a = g.cell(ax, ay), b = g.cell(bx, by);
                reach = std::max(std::abs(a.x - b.x), std::abs(a.y - b.y)) <= 2;
            }
            reach = reach && line_contact(u, t, g);
            if (q) {
                if (q->contacts.size() >= 4096)
                    q->contacts.clear();
                q->contacts[uid] = {ax, ay, bx, by, range, target, atype, btype, reach};
            }
        }
        return (flags & 1) | (reach ? 2 : 0);
    }
    bool overlap_at(const Dictionary &table, Vector2i cell, int64_t uid) {
        Variant raw = table.get(cell, Variant());
        if (raw.get_type() != Variant::DICTIONARY)
            return false;
        Dictionary bucket = raw;
        return bucket.size() > 1 || !bucket.has(uid);
    }
    bool overlaps(const Dictionary &u, const Dictionary &cells, const Dictionary &context) {
        bool water = water_layer(u, context);
        int layer = water ? 1 : 0;
        if (!cells.has(layer))
            return false;
        Dictionary table = cells[layer];
        Geometry g(context, water, k);
        int64_t uid = integer(u, k.uid);
        int cls = shape_class(integer(u, k.unit, -1));
        auto anchor = g.cell(double(u[k.ax]), double(u[k.ay]));
        if (cls == 0)
            return overlap_at(table, anchor, uid);
        Variant raw = u.get(k.occupied_cells, Variant());
        if (raw.get_type() == Variant::ARRAY && !Array(raw).is_empty()) {
            Array occupied = raw;
            for (int64_t i = 0; i < occupied.size(); ++i)
                if (overlap_at(table, occupied[i], uid))
                    return true;
            return false;
        }
        if (boolean(u, k.decor))
            return overlap_at(table, anchor, uid);
        const auto &offsets = shapes[cls][anchor.y & 1];
        if (boolean(u, k.building))
            for (auto offset : offsets)
                if (!g.inside(anchor + offset))
                    return overlap_at(table, anchor, uid);
        for (auto offset : offsets)
            if (overlap_at(table, anchor + offset, uid))
                return true;
        return false;
    }
    Vector4i separation_candidate(const Dictionary &u, const Dictionary &cells,
                                  const Dictionary &context, bool near_only, int64_t cursor) {
        bool water = water_layer(u, context);
        Geometry g(context, water, k);
        const Dictionary table =
            cells.has(water ? 1 : 0) ? Dictionary(cells[water ? 1 : 0]) : Dictionary();
        auto cell = g.cell(double(u[k.ax]), double(u[k.ay]));
        int cls = shape_class(integer(u, k.unit, -1));
        int64_t uid = integer(u, k.uid), index = 0;
        Vector2 origin{real_t(double(u[k.ax])), real_t(double(u[k.ay]))};
        for (int r = 1; r <= (near_only ? 1 : 12); ++r)
            for (int dx = -r; dx <= r; ++dx)
                for (int dy = -r; dy <= r; ++dy) {
                    if (std::max(std::abs(dx), std::abs(dy)) != r)
                        continue;
                    if (index++ < cursor)
                        continue;
                    Vector2i c(std::clamp(cell.x + dx, 0, g.rows - 1),
                               std::clamp(cell.y + dy, 0, g.cols - 1));
                    if (c == cell || !placement(c, cls, uid, g, table) ||
                        !body_clear(origin, g.anchor(c), g, cls))
                        continue;
                    return Vector4i(c.x, c.y, r, index);
                }
        return Vector4i(-1, -1, 0, index);
    }
    int64_t attack_fast(Dictionary u, double delta, const Dictionary &context,
                        const Dictionary &owners, const Dictionary &targets, const Array &units,
                        const Array &indexed, int64_t indexed_size) {
        if (String(u.get(k.state, "")) != attack_state || boolean(u, k.building) ||
            boolean(u, k.attached) || double(u.get(k.burn_t, 0.0)) > 0 ||
            integer(u, k.site, -1) >= 0 || integer(u, k.site_follow_uid, -1) >= 0 || active(u) ||
            integer(u, k.ambush_t) > 0)
            return -1;
        if (integer(u, k.unit, -1) == 47 || double(u.get(k.atk_range, 0.0)) <= 0 ||
            (double(u.get(k.attack, 0.0)) <= 0 && double(u.get(k.attack_b, 0.0)) <= 0))
            return -1;
        if (units.size() != indexed_size || !UtilityFunctions::is_same(units, indexed))
            return -1;
        Variant raw = u.get(k.target_record, Variant());
        if (raw.get_type() != Variant::DICTIONARY)
            return -1;
        Dictionary t = raw;
        if (!boolean(t, k.alive) || double(t.get(k.die_t, -1.0)) >= 0 || boolean(t, k.attached))
            return -1;
        int64_t uid = integer(t, k.uid, -1);
        Variant owner = owners.get(uid, Variant());
        bool found = false;
        if (owner.get_type() != Variant::NIL) {
            Dictionary bucket = targets[owner];
            found = UtilityFunctions::is_same(bucket.get(uid, Variant()), t);
        } else
            for (int64_t i = 0; i < units.size(); ++i)
                if (UtilityFunctions::is_same(units[i], t)) {
                    found = true;
                    break;
                }
        if (!found)
            return -1;
        begin_status(u);
        u[k.moved] = false;
        auto prepared =
            prepare_combat(u, t, double(u[k.atk_range]), double(context[k.w]), false, context);
        if (prepared & 2) {
            u[k.route_failures] = int64_t(0);
            Variant raw_path = u.get(k.path, Variant());
            if (raw_path.get_type() != Variant::ARRAY || !Array(raw_path).is_empty() ||
                Array(raw_path).is_read_only())
                u[k.path] = Array();
            u[k.pi] = int64_t(0);
            return prepared & 1;
        }
        if (prepared & 1)
            reset(u);
        double remaining = double(u.get(k.repath, 0.0)) - delta;
        u[k.repath] = remaining;
        return 4 | (remaining <= 0 ? 2 : 0);
    }
    bool finish_or_separate(Dictionary u, const Dictionary &cells, const Dictionary &context) {
        if (!active(u) && integer(u, k.site, -1) < 0 && boolean(u, k.alive) &&
            double(u.get(k.die_t, -1.0)) < 0 && !boolean(u, k.building) &&
            !boolean(u, k.attached) && overlaps(u, cells, context))
            return true;
        finish_plain_attack(u);
        return false;
    }
    void finish_plain_attack(Dictionary u) {
        if (integer(u, k.rolling) <= 0 && integer(u, k.rolling_ticks) != 0)
            u[k.rolling_ticks] = int64_t(0);
        finish_unit(u);
    }
    void begin_status(Dictionary u) {
        Variant raw = u.get(k.pending, Variant());
        auto task = integer(u, k.task);
        if (task == 0 && (raw.get_type() == Variant::NIL ||
                          (raw.get_type() == Variant::ARRAY && Array(raw).is_empty())))
            return;
        if (active(u) && !task_alive(u, task))
            u[k.task] = int64_t(0);
        Array pending = raw.get_type() == Variant::ARRAY ? Array(raw) : Array();
        while (!active(u) && String(u.get(k.state, "")) == idle_state && !pending.is_empty() &&
               !boolean(u, k.attached) && integer(u, k.site, -1) < 0) {
            auto next = int64_t(pending.pop_front());
            if (task_alive(u, next))
                u[k.task] = next;
        }
        u[k.pending] = pending;
    }
    void step_locomotion(Dictionary u) {
        if (boolean(u, k.building))
            return;
        ensure(u);
        if (boolean(u, k.attached) || integer(u, k.site, -1) >= 0 || active(u))
            return;
        bool moving = boolean(u, k.moved);
        auto desired = integer(u, k.dir) & 7;
        auto facing = integer(u, k.facing);
        bool started = boolean(u, k.moved_started), turning = boolean(u, k.turning);
        auto turn = integer(u, k.turn);
        if (!moving && facing == desired && !started && !turning && turn == 0)
            return;
        if (moving)
            u[k.walk] = integer(u, k.walk) + 1;
        auto state = String(u.get(k.state, ""));
        if (!moving && (state == attack_state || state == repair_state)) {
            u[k.facing] = desired;
            u[k.turning] = false;
            u[k.turn] = int64_t(0);
        } else if (facing != desired) {
            u[k.turning] = true;
            u[k.turn] = ++turn;
            if (turn % frame_ticks == 0) {
                auto difference = (desired - facing + 8) % 8;
                u[k.facing] = (facing + (difference <= 4 ? 1 : -1) + 8) % 8;
            }
        } else if (moving && !started) {
            u[k.turning] = true;
            u[k.turn] = int64_t(1);
        } else if (turning && turn < frame_ticks)
            u[k.turn] = turn + 1;
        else {
            u[k.turning] = false;
            u[k.turn] = int64_t(0);
        }
        u[k.moved_started] = moving;
    }
    void step_timers(Dictionary u) {
        for (int64_t i = 0; i < statuses.size(); ++i) {
            const Variant &key = statuses[i];
            auto remaining = integer(u, key);
            if (remaining > 0)
                u[key] = remaining - 1;
        }
    }
    void finish_unit(Dictionary u) {
        step_locomotion(u);
        step_timers(u);
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("fingerprint"), &ChibiSimulationMath::fingerprint);
        ClassDB::bind_method(D_METHOD("make_unit_port", "fire", "repath", "walk", "yield",
                                      "fallback", "die", "navigation", "abort"),
                             &ChibiSimulationMath::make_unit_port);
        ClassDB::bind_method(D_METHOD("step_units", "units", "delta", "context", "owners",
                                      "targets", "cells", "indexed", "indexed_size", "port",
                                      "profile"),
                             &ChibiSimulationMath::step_units);

        ClassDB::bind_method(D_METHOD("make_query", "context"), &ChibiSimulationMath::make_query);
        ClassDB::bind_method(D_METHOD("finish_or_separate", "unit", "cells", "context"),
                             &ChibiSimulationMath::finish_or_separate);
        ClassDB::bind_method(D_METHOD("update_visibility", "units", "player", "width", "height",
                                      "cell", "current", "explored", "reveals", "sources",
                                      "full_reveal", "farsight_cells"),
                             &ChibiSimulationMath::update_visibility);
        ClassDB::bind_method(D_METHOD("configure", "fields", "clip", "ticks", "confusion",
                                      "rolling", "classes", "offsets", "naval"),
                             &ChibiSimulationMath::configure);
        ClassDB::bind_method(D_METHOD("step_clock", "unit", "kind", "target", "building"),
                             &ChibiSimulationMath::step_clock);
        ClassDB::bind_method(
            D_METHOD("prepare_attack", "unit", "target", "range", "width", "tower"),
            &ChibiSimulationMath::prepare_attack);
        ClassDB::bind_method(
            D_METHOD("prepare_combat", "unit", "target", "range", "width", "tower", "context"),
            &ChibiSimulationMath::prepare_combat);
        ClassDB::bind_method(D_METHOD("overlaps", "unit", "cells", "context"),
                             &ChibiSimulationMath::overlaps);
        ClassDB::bind_method(
            D_METHOD("separation_candidate", "unit", "cells", "context", "near_only", "cursor"),
            &ChibiSimulationMath::separation_candidate);
        ClassDB::bind_method(D_METHOD("attack_fast", "unit", "delta", "context", "owners",
                                      "targets", "units", "indexed", "indexed_size"),
                             &ChibiSimulationMath::attack_fast);
        ClassDB::bind_method(D_METHOD("finish_plain_attack", "unit"),
                             &ChibiSimulationMath::finish_plain_attack);
        ClassDB::bind_method(D_METHOD("begin_status", "unit"), &ChibiSimulationMath::begin_status);
        ClassDB::bind_method(D_METHOD("step_locomotion", "unit"),
                             &ChibiSimulationMath::step_locomotion);
        ClassDB::bind_method(D_METHOD("step_timers", "unit"), &ChibiSimulationMath::step_timers);
        ClassDB::bind_method(D_METHOD("finish_unit", "unit"), &ChibiSimulationMath::finish_unit);
    }
};
void initialize_math(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<ChibiUnitCommands>();
        ClassDB::register_class<ChibiNavigationQuery>();
        ClassDB::register_class<ChibiSimulationMath>();
    }
}
extern "C" GDExtensionBool GDE_EXPORT sim_math_init(GDExtensionInterfaceGetProcAddress get_proc,
                                                    const GDExtensionClassLibraryPtr library,
                                                    GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize_math);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
