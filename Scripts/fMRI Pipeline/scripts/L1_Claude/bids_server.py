#!/usr/bin/env python3
"""
BIDS Interactive Viewer - Flask Server
A local web server for browsing BIDS datasets with PyBIDS integration.

Usage:
    python bids_server.py

Then open: http://localhost:5000
"""

import os
import json
import subprocess
import platform
from pathlib import Path
from flask import Flask, render_template_string, jsonify, request, send_from_directory
from flask_cors import CORS

# Try to import required packages
try:
    from bids import BIDSLayout
    PYBIDS_AVAILABLE = True
except ImportError:
    PYBIDS_AVAILABLE = False
    print("Warning: PyBIDS not available. Install with: pip install pybids")

try:
    import pandas as pd
    PANDAS_AVAILABLE = True
except ImportError:
    PANDAS_AVAILABLE = False
    print("Warning: pandas not available. Install with: pip install pandas")

try:
    import nibabel as nib
    NIBABEL_AVAILABLE = True
except ImportError:
    NIBABEL_AVAILABLE = False
    print("Warning: nibabel not available. Install with: pip install nibabel")

app = Flask(__name__)
CORS(app)  # Enable CORS for local development

# Global variables
current_layout = None
current_bids_path = ""

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BIDS Interactive Viewer</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .content {
            padding: 30px;
        }
        
        .section {
            margin-bottom: 30px;
            border: 2px solid #f0f0f0;
            border-radius: 10px;
            padding: 20px;
            background: #fafafa;
        }
        
        .section h2 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.5em;
        }
        
        .directory-input {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }
        
        .directory-input input {
            flex: 1;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
        }
        
        .directory-input input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
            text-align: center;
        }
        
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        
        .btn-primary {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
        }
        
        .btn-primary:hover:not(:disabled) {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.3);
        }
        
        .btn-secondary {
            background: #f8f9fa;
            color: #333;
            border: 2px solid #ddd;
        }
        
        .btn-secondary:hover:not(:disabled) {
            background: #e9ecef;
            transform: translateY(-1px);
        }
        
        .btn-success {
            background: #28a745;
            color: white;
        }
        
        .btn-success:hover:not(:disabled) {
            background: #218838;
            transform: translateY(-2px);
        }
        
        .btn-info {
            background: #17a2b8;
            color: white;
        }
        
        .btn-info:hover:not(:disabled) {
            background: #138496;
            transform: translateY(-2px);
        }
        
        .btn-warning {
            background: #ffc107;
            color: #212529;
        }
        
        .btn-warning:hover:not(:disabled) {
            background: #e0a800;
            transform: translateY(-2px);
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
            gap: 10px;
            margin-top: 15px;
        }
        
        .file-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        
        .file-item {
            background: white;
            border: 2px solid #e9ecef;
            border-radius: 8px;
            padding: 15px;
            transition: all 0.3s ease;
        }
        
        .file-item:hover {
            border-color: #667eea;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        
        .file-name {
            font-weight: 600;
            color: #333;
            margin-bottom: 8px;
            font-size: 14px;
            word-break: break-word;
        }
        
        .file-path {
            font-size: 12px;
            color: #666;
            margin-bottom: 10px;
            word-break: break-all;
        }
        
        .file-metadata {
            font-size: 11px;
            color: #888;
            margin-bottom: 10px;
            background: #f8f9fa;
            padding: 5px;
            border-radius: 4px;
        }
        
        .file-actions {
            display: flex;
            gap: 5px;
            flex-wrap: wrap;
        }
        
        .status {
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
        
        .status.info {
            background: #d1ecf1;
            color: #0c5460;
            border: 1px solid #bee5eb;
        }
        
        .status.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .status.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        #fileViewer {
            background: #f8f9fa;
            border: 2px solid #dee2e6;
            border-radius: 8px;
            padding: 20px;
            margin-top: 20px;
            max-height: 600px;
            overflow-y: auto;
        }
        
        .hidden {
            display: none;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
        }
        
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .current-selection {
            background: linear-gradient(45deg, #28a745, #20c997);
            color: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        
        .stat-card {
            background: white;
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
        }
        
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
        
        pre {
            background: #f8f9fa;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            overflow-x: auto;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧠 BIDS Interactive Viewer</h1>
            <p>Local server with PyBIDS integration</p>
        </div>
        
        <div class="content">
            <!-- Directory Selection -->
            <div class="section">
                <h2>📁 BIDS Directory</h2>
                <div class="directory-input">
                    <input type="text" id="bidsPath" placeholder="Enter BIDS dataset path..." 
                           value="/data00/projects/georemote_fmri/data/bids_data/">
                    <button class="btn btn-primary" onclick="loadBidsDirectory()">Load Directory</button>
                </div>
                <div id="directoryStatus" class="status info">
                    PyBIDS Available: {{ pybids_available }}, 
                    Pandas Available: {{ pandas_available }}, 
                    NiBabel Available: {{ nibabel_available }}
                </div>
            </div>
            
            <!-- Dataset Stats -->
            <div id="statsSection" class="section hidden">
                <h2>📊 Dataset Statistics</h2>
                <div id="statsGrid" class="stats-grid"></div>
            </div>
            
            <!-- Current Selection Display -->
            <div id="currentSelection" class="current-selection hidden">
                <strong>Current Selection:</strong> <span id="selectionText">None</span>
            </div>
            
            <!-- Participants Section -->
            <div class="section">
                <h2>👥 Participants</h2>
                <div id="participantStatus" class="status info">
                    Load a BIDS directory to see participants
                </div>
                <div id="participantGrid" class="grid hidden"></div>
            </div>
            
            <!-- File Types Section -->
            <div id="fileTypesSection" class="section hidden">
                <h2>📊 Data Types</h2>
                <div class="grid">
                    <button class="btn btn-secondary" onclick="loadFileType('func')">
                        🧠 Functional
                    </button>
                    <button class="btn btn-secondary" onclick="loadFileType('anat')">
                        🏗️ Anatomical
                    </button>
                    <button class="btn btn-secondary" onclick="loadFileType('dwi')">
                        🔗 Diffusion
                    </button>
                    <button class="btn btn-secondary" onclick="loadFileType('fmap')">
                        🗺️ Fieldmaps
                    </button>
                    <button class="btn btn-secondary" onclick="loadFileType('events')">
                        📋 Events
                    </button>
                    <button class="btn btn-secondary" onclick="loadFileType('derivatives')">
                        🔬 Derivatives
                    </button>
                </div>
            </div>
            
            <!-- Files Section -->
            <div id="filesSection" class="section hidden">
                <h2 id="filesTitle">📄 Files</h2>
                <div id="filesGrid" class="file-grid"></div>
            </div>
            
            <!-- File Viewer Section -->
            <div id="viewerSection" class="section hidden">
                <h2>👀 File Viewer</h2>
                <div id="fileViewer"></div>
            </div>
        </div>
    </div>

    <script>
        // Global state
        let currentBidsPath = '';
        let currentParticipant = '';
        let currentFileType = '';
        let currentFile = '';
        
        function updateSelection() {
            const selectionDiv = document.getElementById('currentSelection');
            const selectionText = document.getElementById('selectionText');
            
            let text = [];
            if (currentBidsPath) text.push(`Directory: ${currentBidsPath}`);
            if (currentParticipant) text.push(`Participant: ${currentParticipant}`);
            if (currentFileType) text.push(`Type: ${currentFileType}`);
            if (currentFile) text.push(`File: ${currentFile.split('/').pop()}`);
            
            if (text.length > 0) {
                selectionText.textContent = text.join(' | ');
                selectionDiv.classList.remove('hidden');
            } else {
                selectionDiv.classList.add('hidden');
            }
        }
        
        function showStatus(elementId, message, type = 'info') {
            const element = document.getElementById(elementId);
            element.textContent = message;
            element.className = `status ${type}`;
            element.classList.remove('hidden');
        }
        
        async function loadBidsDirectory() {
            const path = document.getElementById('bidsPath').value.trim();
            if (!path) {
                showStatus('directoryStatus', 'Please enter a valid path', 'error');
                return;
            }
            
            showStatus('directoryStatus', `Loading BIDS layout from ${path}...`, 'info');
            
            try {
                const response = await fetch('/api/load_directory', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({path: path})
                });
                
                const data = await response.json();
                
                if (data.success) {
                    currentBidsPath = path;
                    updateSelection();
                    displayParticipants(data.participants);
                    displayStats(data.stats);
                    showStatus('directoryStatus', `Successfully loaded ${data.participants.length} participants`, 'success');
                } else {
                    showStatus('directoryStatus', `Error: ${data.error}`, 'error');
                }
            } catch (error) {
                showStatus('directoryStatus', `Network error: ${error.message}`, 'error');
            }
        }
        
        function displayStats(stats) {
            const grid = document.getElementById('statsGrid');
            const section = document.getElementById('statsSection');
            
            grid.innerHTML = '';
            
            Object.entries(stats).forEach(([key, value]) => {
                const card = document.createElement('div');
                card.className = 'stat-card';
                card.innerHTML = `
                    <div class="stat-number">${value}</div>
                    <div class="stat-label">${key.replace('_', ' ').toUpperCase()}</div>
                `;
                grid.appendChild(card);
            });
            
            section.classList.remove('hidden');
        }
        
        function displayParticipants(participants) {
            const grid = document.getElementById('participantGrid');
            const status = document.getElementById('participantStatus');
            
            if (participants.length === 0) {
                showStatus('participantStatus', 'No participants found', 'error');
                return;
            }
            
            grid.innerHTML = '';
            participants.forEach(participant => {
                const button = document.createElement('button');
                button.className = 'btn btn-secondary';
                button.textContent = participant;
                button.onclick = () => selectParticipant(participant);
                grid.appendChild(button);
            });
            
            grid.classList.remove('hidden');
            status.classList.add('hidden');
        }
        
        function selectParticipant(participant) {
            currentParticipant = participant;
            currentFileType = '';
            currentFile = '';
            updateSelection();
            
            // Show file types section
            document.getElementById('fileTypesSection').classList.remove('hidden');
            document.getElementById('filesSection').classList.add('hidden');
            document.getElementById('viewerSection').classList.add('hidden');
            
            // Highlight selected participant
            document.querySelectorAll('#participantGrid .btn').forEach(btn => {
                btn.classList.remove('btn-primary');
                btn.classList.add('btn-secondary');
            });
            event.target.classList.remove('btn-secondary');
            event.target.classList.add('btn-primary');
        }
        
        async function loadFileType(type) {
            if (!currentParticipant) {
                alert('Please select a participant first');
                return;
            }
            
            currentFileType = type;
            currentFile = '';
            updateSelection();
            
            showStatus('directoryStatus', `Loading ${type} files for ${currentParticipant}...`, 'info');
            
            try {
                const response = await fetch('/api/get_files', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        participant: currentParticipant,
                        file_type: type
                    })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    displayFiles(data.files, type);
                    showStatus('directoryStatus', `Found ${data.files.length} ${type} files`, 'success');
                } else {
                    showStatus('directoryStatus', `Error: ${data.error}`, 'error');
                }
            } catch (error) {
                showStatus('directoryStatus', `Network error: ${error.message}`, 'error');
            }
        }
        
        function displayFiles(files, type) {
            const grid = document.getElementById('filesGrid');
            const title = document.getElementById('filesTitle');
            const section = document.getElementById('filesSection');
            
            title.textContent = `📄 ${type.toUpperCase()} Files - ${currentParticipant}`;
            
            grid.innerHTML = '';
            files.forEach(file => {
                const fileItem = createFileItem(file);
                grid.appendChild(fileItem);
            });
            
            section.classList.remove('hidden');
        }
        
        function createFileItem(file) {
            const item = document.createElement('div');
            item.className = 'file-item';
            
            const fileName = file.path.split('/').pop();
            const metadata = file.metadata ? JSON.stringify(file.metadata, null, 2) : 'No metadata available';
            
            item.innerHTML = `
                <div class="file-name">${fileName}</div>
                <div class="file-path">${file.path}</div>
                ${file.metadata ? `<div class="file-metadata">${Object.entries(file.metadata).slice(0, 3).map(([k,v]) => `${k}: ${v}`).join(', ')}</div>` : ''}
                <div class="file-actions">
                    <button class="btn btn-success" onclick="viewFile('${file.path}')">
                        👀 View
                    </button>
                    ${getViewerButtons(file)}
                </div>
            `;
            
            return item;
        }
        
        function getViewerButtons(file) {
            let buttons = '';
            const path = file.path;
            const fileName = path.split('/').pop();
            
            if (fileName.endsWith('.nii.gz') || fileName.endsWith('.nii')) {
                buttons += `
                    <button class="btn btn-info" onclick="openInFSLeyes('${path}')">
                        🔍 FSLeyes
                    </button>
                `;
            }
            
            if (fileName.endsWith('.html')) {
                buttons += `
                    <button class="btn btn-warning" onclick="openInBrowser('${path}')">
                        🌐 Browser
                    </button>
                `;
            }
            
            buttons += `
                <button class="btn btn-secondary" onclick="copyPath('${path}')">
                    📋 Copy
                </button>
            `;
            
            return buttons;
        }
        
        async function viewFile(filePath) {
            currentFile = filePath;
            updateSelection();
            
            const viewer = document.getElementById('fileViewer');
            const section = document.getElementById('viewerSection');
            
            // Show loading
            viewer.innerHTML = '<div class="loading"><div class="spinner"></div><p>Loading file...</p></div>';
            section.classList.remove('hidden');
            
            try {
                const response = await fetch('/api/view_file', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({path: filePath})
                });
                
                const data = await response.json();
                
                if (data.success) {
                    viewer.innerHTML = data.content;
                } else {
                    viewer.innerHTML = `<div class="status error">Error: ${data.error}</div>`;
                }
            } catch (error) {
                viewer.innerHTML = `<div class="status error">Network error: ${error.message}</div>`;
            }
        }
        
        async function openInFSLeyes(filePath) {
            try {
                const response = await fetch('/api/open_fsleyes', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({path: filePath})
                });
                
                const data = await response.json();
                
                if (data.success) {
                    showStatus('directoryStatus', 'FSLeyes launched successfully', 'success');
                } else {
                    alert(`Failed to launch FSLeyes: ${data.error}`);
                }
            } catch (error) {
                alert(`Network error: ${error.message}`);
            }
        }
        
        function openInBrowser(filePath) {
            window.open(`/view_html?path=${encodeURIComponent(filePath)}`, '_blank');
        }
        
        function copyPath(filePath) {
            navigator.clipboard.writeText(filePath).then(() => {
                showStatus('directoryStatus', 'File path copied to clipboard!', 'success');
            }).catch(() => {
                prompt('Copy this path:', filePath);
            });
        }
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Serve the main HTML page."""
    return render_template_string(HTML_TEMPLATE, 
                                pybids_available=PYBIDS_AVAILABLE,
                                pandas_available=PANDAS_AVAILABLE,
                                nibabel_available=NIBABEL_AVAILABLE)

@app.route('/api/load_directory', methods=['POST'])
def load_directory():
    """Load a BIDS directory and return participant information."""
    global current_layout, current_bids_path
    
    data = request.get_json()
    bids_path = data.get('path', '')
    
    if not os.path.exists(bids_path):
        return jsonify({'success': False, 'error': 'Directory does not exist'})
    
    try:
        if PYBIDS_AVAILABLE:
            # Use PyBIDS to load the dataset
            current_layout = BIDSLayout(bids_path, validate=False)
            participants = current_layout.get_subjects()
            
            # Get dataset statistics
            stats = {
                'participants': len(participants),
                'sessions': len(current_layout.get_sessions()),
                'runs': len(current_layout.get_runs()),
                'tasks': len(current_layout.get_tasks())
            }
        else:
            # Fallback: manual directory scanning
            participants = []
            for item in os.listdir(bids_path):
                if item.startswith('sub-') and os.path.isdir(os.path.join(bids_path, item)):
                    participants.append(item.replace('sub-', ''))
            
            stats = {
                'participants': len(participants),
                'sessions': 0,
                'runs': 0,
                'tasks': 0
            }
        
        current_bids_path = bids_path
        
        return jsonify({
            'success': True,
            'participants': sorted(participants),
            'stats': stats
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/get_files', methods=['POST'])
def get_files():
    """Get files for a specific participant and file type."""
    global current_layout
    
    data = request.get_json()
    participant = data.get('participant', '')
    file_type = data.get('file_type', '')
    
    if not current_layout and not current_bids_path:
        return jsonify({'success': False, 'error': 'No BIDS directory loaded'})
    
    try:
        files = []
        
        if current_layout and PYBIDS_AVAILABLE:
            # Use PyBIDS to get files
            if file_type == 'derivatives':
                # Look for derivatives
                derivative_files = []
                derivatives_dir = os.path.join(current_bids_path, 'derivatives')
                if os.path.exists(derivatives_dir):
                    for root, dirs, filenames in os.walk(derivatives_dir):
                        for filename in filenames:
                            if f'sub-{participant}' in filename:
                                filepath = os.path.join(root, filename)
                                derivative_files.append({
                                    'path': filepath,
                                    'metadata': {'type': 'derivative', 'size': os.path.getsize(filepath)}
                                })
                
                # Also look for derivatives in the same directory
                for item in os.listdir(current_bids_path):
                    if 'derivatives' in item.lower() and os.path.isdir(os.path.join(current_bids_path, item)):
                        deriv_path = os.path.join(current_bids_path, item)
                        for root, dirs, filenames in os.walk(deriv_path):
                            for filename in filenames:
                                if f'sub-{participant}' in filename:
                                    filepath = os.path.join(root, filename)
                                    derivative_files.append({
                                        'path': filepath,
                                        'metadata': {'type': 'derivative', 'size': os.path.getsize(filepath)}
                                    })
                
                files = derivative_files
            
            elif file_type == 'events':
                # Get events files
                event_files = current_layout.get(subject=participant, extension='.tsv', suffix='events', return_type='filename')
                for filepath in event_files:
                    try:
                        # Try to get metadata
                        bids_file = current_layout.get_file(filepath)
                        metadata = bids_file.get_metadata() if hasattr(bids_file, 'get_metadata') else {}
                        files.append({
                            'path': filepath,
                            'metadata': metadata
                        })
                    except:
                        files.append({
                            'path': filepath,
                            'metadata': {}
                        })
            
            else:
                # Get files by datatype (func, anat, dwi, fmap)
                if file_type in ['func', 'anat', 'dwi', 'fmap']:
                    bids_files = current_layout.get(subject=participant, datatype=file_type, return_type='filename')
                    for filepath in bids_files:
                        try:
                            # Try to get metadata
                            bids_file = current_layout.get_file(filepath)
                            metadata = bids_file.get_metadata() if hasattr(bids_file, 'get_metadata') else {}
                            files.append({
                                'path': filepath,
                                'metadata': metadata
                            })
                        except:
                            files.append({
                                'path': filepath,
                                'metadata': {}
                            })
        else:
            # Fallback: manual file scanning
            participant_dir = os.path.join(current_bids_path, f'sub-{participant}')
            if os.path.exists(participant_dir):
                for root, dirs, filenames in os.walk(participant_dir):
                    for filename in filenames:
                        filepath = os.path.join(root, filename)
                        if file_type == 'events' and 'events' in filename and filename.endswith('.tsv'):
                            files.append({'path': filepath, 'metadata': {}})
                        elif file_type in ['func', 'anat', 'dwi', 'fmap'] and file_type in root:
                            files.append({'path': filepath, 'metadata': {}})
                        elif file_type == 'derivatives':
                            # Handle derivatives separately
                            pass
        
        return jsonify({
            'success': True,
            'files': files
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/view_file', methods=['POST'])
def view_file():
    """View file content."""
    data = request.get_json()
    filepath = data.get('path', '')
    
    if not os.path.exists(filepath):
        return jsonify({'success': False, 'error': 'File does not exist'})
    
    try:
        file_ext = os.path.splitext(filepath)[1].lower()
        filename = os.path.basename(filepath)
        
        content = f'<h3>📄 {filename}</h3><hr><br>'
        content += f'<p><strong>Path:</strong> <code>{filepath}</code></p>'
        content += f'<p><strong>Size:</strong> {os.path.getsize(filepath) / (1024*1024):.2f} MB</p>'
        
        if file_ext in ['.nii', '.gz'] and filepath.endswith('.nii.gz'):
            # NIfTI file
            if NIBABEL_AVAILABLE:
                try:
                    img = nib.load(filepath)
                    header = img.header
                    data = img.get_fdata()
                    
                    content += f'<h4>NIfTI Information:</h4>'
                    content += f'<p><strong>Shape:</strong> {img.shape}</p>'
                    content += f'<p><strong>Data type:</strong> {header.get_data_dtype()}</p>'
                    content += f'<p><strong>Voxel size:</strong> {header.get_zooms()}</p>'
                    content += f'<h4>Data Statistics:</h4>'
                    content += f'<p><strong>Min:</strong> {data.min():.4f}</p>'
                    content += f'<p><strong>Max:</strong> {data.max():.4f}</p>'
                    content += f'<p><strong>Mean:</strong> {data.mean():.4f}</p>'
                    content += f'<p><strong>Std:</strong> {data.std():.4f}</p>'
                    
                    # Add viewer recommendations
                    content += f'<h4>Recommended Actions:</h4>'
                    content += f'<button class="btn btn-info" onclick="openInFSLeyes(\'{filepath}\')">🔍 Open in FSLeyes</button>'
                    
                except Exception as e:
                    content += f'<p><strong>Error loading NIfTI:</strong> {str(e)}</p>'
            else:
                content += f'<p><em>Install nibabel to view NIfTI file details</em></p>'
                content += f'<button class="btn btn-info" onclick="openInFSLeyes(\'{filepath}\')">🔍 Open in FSLeyes</button>'
        
        elif file_ext == '.tsv':
            # TSV file (events, etc.)
            if PANDAS_AVAILABLE:
                try:
                    df = pd.read_csv(filepath, sep='\t')
                    content += f'<h4>TSV File Information:</h4>'
                    content += f'<p><strong>Shape:</strong> {df.shape}</p>'
                    content += f'<p><strong>Columns:</strong> {", ".join(df.columns)}</p>'
                    
                    if 'trial_type' in df.columns:
                        unique_trials = df['trial_type'].unique()
                        content += f'<p><strong>Trial types:</strong> {", ".join(map(str, unique_trials))}</p>'
                    
                    content += f'<h4>Preview (first 10 rows):</h4>'
                    content += f'<pre>{df.head(10).to_string()}</pre>'
                    
                except Exception as e:
                    content += f'<p><strong>Error loading TSV:</strong> {str(e)}</p>'
            else:
                content += f'<p><em>Install pandas to view TSV file details</em></p>'
        
        elif file_ext == '.json':
            # JSON file
            try:
                with open(filepath, 'r') as f:
                    json_data = json.load(f)
                
                content += f'<h4>JSON Content:</h4>'
                content += f'<pre>{json.dumps(json_data, indent=2)}</pre>'
                
            except Exception as e:
                content += f'<p><strong>Error loading JSON:</strong> {str(e)}</p>'
        
        elif file_ext == '.html':
            # HTML file
            content += f'<p><strong>File Type:</strong> HTML Report</p>'
            content += f'<button class="btn btn-warning" onclick="openInBrowser(\'{filepath}\')">🌐 Open in Browser</button>'
            content += f'<p><em>Click the button above to view this HTML report in a new tab.</em></p>'
        
        else:
            # Generic file
            content += f'<p><strong>File Type:</strong> {file_ext or "Unknown"}</p>'
            content += f'<p><em>Preview not available for this file type.</em></p>'
        
        return jsonify({'success': True, 'content': content})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/open_fsleyes', methods=['POST'])
def open_fsleyes():
    """Launch FSLeyes with the specified file."""
    data = request.get_json()
    filepath = data.get('path', '')
    
    if not os.path.exists(filepath):
        return jsonify({'success': False, 'error': 'File does not exist'})
    
    try:
        # Try to launch FSLeyes
        if platform.system() == "Darwin":  # macOS
            subprocess.Popen(['open', '-a', 'FSLeyes', filepath])
        elif platform.system() == "Windows":
            subprocess.Popen(['fsleyes', filepath], shell=True)
        else:  # Linux
            subprocess.Popen(['fsleyes', filepath])
        
        return jsonify({'success': True, 'message': 'FSLeyes launched'})
        
    except FileNotFoundError:
        return jsonify({'success': False, 'error': 'FSLeyes not found. Please install FSLeyes and make sure it\'s in your PATH.'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/view_html')
def view_html():
    """Serve HTML files directly."""
    filepath = request.args.get('path', '')
    
    if not os.path.exists(filepath):
        return "File not found", 404
    
    try:
        # Read the HTML file and serve it
        with open(filepath, 'r', encoding='utf-8') as f:
            html_content = f.read()
        
        # Fix relative paths in the HTML
        base_dir = os.path.dirname(filepath)
        
        # Replace relative image/resource paths
        import re
        
        # Fix src="./..." paths
        def fix_src_path(match):
            relative_path = match.group(1)
            if relative_path.startswith('./'):
                absolute_path = os.path.join(base_dir, relative_path[2:])
                # Convert to a route that can serve the file
                return f'src="/serve_file?path={absolute_path}"'
            return match.group(0)
        
        html_content = re.sub(r'src="(\./[^"]*)"', fix_src_path, html_content)
        
        return html_content
        
    except Exception as e:
        return f"Error loading HTML file: {str(e)}", 500

@app.route('/serve_file')
def serve_file():
    """Serve any file (for HTML resources like images, CSS, etc.)."""
    filepath = request.args.get('path', '')
    
    if not os.path.exists(filepath):
        return "File not found", 404
    
    # Get the directory and filename
    directory = os.path.dirname(filepath)
    filename = os.path.basename(filepath)
    
    return send_from_directory(directory, filename)

def main():
    """Main function to run the Flask server."""
    print("="*60)
    print("        BIDS INTERACTIVE VIEWER - LOCAL SERVER")
    print("="*60)
    print(f"PyBIDS Available: {PYBIDS_AVAILABLE}")
    print(f"Pandas Available: {PANDAS_AVAILABLE}")
    print(f"NiBabel Available: {NIBABEL_AVAILABLE}")
    print()
    print("Starting server...")
    print("Open your browser and go to: http://localhost:5000")
    print()
    print("To stop the server, press Ctrl+C")
    print("="*60)
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5000, debug=True)

if __name__ == '__main__':
    main()