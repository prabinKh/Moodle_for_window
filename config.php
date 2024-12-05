<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'db';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodleuser';
$CFG->dbpass    = 'MoodlePass@123';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '',
);

$CFG->wwwroot   = 'http://10.40.0.71';
$CFG->dataroot  = '/var/www/moodledata';
$CFG->dirroot   = '/var/www/html';
$CFG->admin     = 'admin';
$CFG->directorypermissions = 0777;

// Prevent upgrade checks and maintenance mode
$CFG->disableupdatenotifications = true;
$CFG->disableupdateautodeploy = true;
$CFG->maintenance_enabled = 0;
$CFG->upgradekey = 'put_some_unique_key_here';

// Debug settings
$CFG->debug = 32767;
$CFG->debugdisplay = 1;

require_once(__DIR__ . '/lib/setup.php'); 
