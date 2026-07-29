<?php

namespace App\Constants;

/**
 * Roles constants for Livi@se.
 * 
 * Defines all available roles for the application with hierarchy
 * and permission levels for access control.
 */
abstract class Roles
{
    public const MICROEMPRESARIO = 'microempresario';
    public const DOCENTE = 'docente';
    public const DOCENTE_ADMIN = 'docente_admin';
    public const ADMIN_TI = 'admin_ti';

    public const LEGACY_ADMIN = 'admin';
    public const LEGACY_COORD = 'coord';
    public const LEGACY_COORDINADOR = 'coordinador';
    public const LEGACY_EDUCADOR = 'educador';
    public const LEGACY_USUARIO = 'usuario';
    public const LEGACY_EMPRENDEDOR = 'emprendedor';

    public const DEFAULT = self::MICROEMPRESARIO;

    /**
     * All available roles in the system.
     */
    public const ALL = [
        self::MICROEMPRESARIO,
        self::DOCENTE,
        self::DOCENTE_ADMIN,
        self::ADMIN_TI,
        self::LEGACY_ADMIN,
        self::LEGACY_COORD,
        self::LEGACY_COORDINADOR,
        self::LEGACY_EDUCADOR,
        self::LEGACY_USUARIO,
        self::LEGACY_EMPRENDEDOR,
    ];

    /**
     * Roles that require active status check.
     */
    public const ACTIVE_ROLES = [
        self::MICROEMPRESARIO,
        self::DOCENTE,
        self::DOCENTE_ADMIN,
        self::ADMIN_TI,
    ];

    /**
     * Roles that can manage users.
     */
    public const MANAGE_USERS = [
        self::ADMIN_TI,
        self::LEGACY_ADMIN,
    ];

    /**
     * Roles that can view sensitive data.
     */
    public const VIEW_SENSITIVE = [
        self::DOCENTE_ADMIN,
        self::ADMIN_TI,
        self::LEGACY_ADMIN,
    ];

    /**
     * Roles that can create/edit content.
     */
    public const MANAGE_CONTENT = [
        self::DOCENTE,
        self::DOCENTE_ADMIN,
        self::LEGACY_EDUCADOR,
    ];

    /**
     * Check if a role is valid.
     */
    public static function isValid(string $role): bool
    {
        return in_array($role, self::ALL, true);
    }

    public static function normalize(string $role): string
    {
        return match ($role) {
            self::LEGACY_ADMIN => self::ADMIN_TI,
            self::LEGACY_COORD, self::LEGACY_COORDINADOR => self::DOCENTE_ADMIN,
            self::LEGACY_EDUCADOR => self::DOCENTE,
            self::LEGACY_USUARIO, self::LEGACY_EMPRENDEDOR => self::MICROEMPRESARIO,
            self::DOCENTE_ADMIN, self::DOCENTE, self::ADMIN_TI, self::MICROEMPRESARIO => $role,
            default => self::MICROEMPRESARIO,
        };
    }

    /**
     * Roles that can be assigned from admin interfaces.
     *
     * @return array<int, string>
     */
    public static function active(): array
    {
        return self::ACTIVE_ROLES;
    }

    /**
     * Check if role requires active status.
     */
    public static function requiresActive(string $role): bool
    {
        return in_array(self::normalize($role), self::ACTIVE_ROLES, true);
    }

    /**
     * Check if role can manage users.
     */
    public static function canManageUsers(string $role): bool
    {
        return in_array($role, self::MANAGE_USERS, true)
            || self::normalize($role) === self::ADMIN_TI;
    }

    /**
     * Check if role can view sensitive data.
     */
    public static function canViewSensitive(string $role): bool
    {
        return in_array($role, self::VIEW_SENSITIVE, true)
            || in_array(self::normalize($role), [self::DOCENTE_ADMIN, self::ADMIN_TI], true);
    }

    /**
     * Check if role can manage content.
     */
    public static function canManageContent(string $role): bool
    {
        return in_array($role, self::MANAGE_CONTENT, true)
            || in_array(self::normalize($role), [self::DOCENTE, self::DOCENTE_ADMIN], true);
    }

    public static function isTeacher(string $role): bool
    {
        return in_array(self::normalize($role), [self::DOCENTE, self::DOCENTE_ADMIN], true);
    }

    /**
     * Get role display name (Spanish).
     */
    public static function getDisplayName(string $role): string
    {
        return match ($role) {
            self::ADMIN_TI, self::LEGACY_ADMIN => 'Experto TI / Administrador del Sistema',
            self::DOCENTE_ADMIN, self::LEGACY_COORD, self::LEGACY_COORDINADOR => 'Docente Administrador / Coordinador Académico',
            self::DOCENTE, self::LEGACY_EDUCADOR => 'Docente / Experto Académico',
            self::MICROEMPRESARIO, self::LEGACY_USUARIO, self::LEGACY_EMPRENDEDOR => 'Microempresario',
            default => 'Microempresario',
        };
    }
}
