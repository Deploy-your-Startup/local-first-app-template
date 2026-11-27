/**
 * Project identity used for user-visible text and for the names of browser
 * storage. Changing these values changes where existing tasks are stored.
 *
 * Derived names use template literals so the rendered file stays
 * Prettier-stable regardless of the length of the project name.
 */
export const PROJECT_NAME = "§§deploy_your_startup.project_name§§";

export const APP_TITLE = "§§deploy_your_startup.app_title§§";

export const DATABASE_FILE = `/${PROJECT_NAME}.sqlite3`;

export const DATABASE_POOL_NAME = PROJECT_NAME;

export const DATABASE_LOCK_NAME = `${PROJECT_NAME}-database-owner`;
