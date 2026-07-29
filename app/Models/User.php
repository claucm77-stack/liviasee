<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Constants\Roles;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'firebase_uid',
        'photo_url',
        'photo_path',
        'teacher_description',
        'name',
        'email',
        'password',
        'role',
        'is_active',
    ];

    public function photoUrl(): string
    {
        if ($this->photo_path) {
            return route('api.profile-photo', $this);
        }

        return (string) ($this->photo_url ?? '');
    }

    public function hasMicrobusiness(): bool
    {
        $ownerIds = array_filter([
            $this->firebase_uid,
            (string) $this->id,
        ]);

        return Microbusiness::query()->whereIn('owner_id', $ownerIds)->exists();
    }

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Check if user is admin.
     */
    public function isAdmin(): bool
    {
        return Roles::canManageUsers($this->role);
    }

    /**
     * Check if user is active.
     */
    public function isActive(): bool
    {
        return $this->is_active === true;
    }

    /**
     * Check if user has specific role.
     */
    public function hasRole(string $role): bool
    {
        return Roles::normalize($this->role) === Roles::normalize($role);
    }

    /**
     * Check if user has any of the given roles.
     */
    public function hasAnyRole(array $roles): bool
    {
        return in_array(Roles::normalize($this->role), array_map([Roles::class, 'normalize'], $roles), true);
    }

    /**
     * Check if user can manage users.
     */
    public function canManageUsers(): bool
    {
        return Roles::canManageUsers($this->role);
    }

    /**
     * Check if user can view sensitive data.
     */
    public function canViewSensitive(): bool
    {
        return Roles::canViewSensitive($this->role);
    }

    /**
     * Check if user can manage content.
     */
    public function canManageContent(): bool
    {
        return Roles::canManageContent($this->role);
    }

    /**
     * Get role display name.
     */
    public function getRoleDisplayName(): string
    {
        return Roles::getDisplayName($this->role);
    }

    /**
     * Roles that belong to this user.
     */
    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class, 'user_roles');
    }

    /**
     * Permissions that belong to this user.
     */
    public function permissions(): BelongsToMany
    {
        return $this->belongsToMany(Permission::class, 'user_permissions');
    }

    /**
     * Check if user has specific permission.
     */
    public function hasPermission(string $permission): bool
    {
        // Check direct permissions
        if ($this->permissions()->where('name', $permission)->exists()) {
            return true;
        }

        // Check role permissions
        foreach ($this->roles()->get() as $role) {
            if ($role->hasPermission($permission)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Scope to filter active users.
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope to filter users by role.
     */
    public function scopeRole($query, string $role)
    {
        return $query->where('role', $role);
    }

    /**
     * Audit logs for this user.
     */
    public function auditLogs()
    {
        return $this->hasMany(AuditLog::class, 'user_id');
    }
}
