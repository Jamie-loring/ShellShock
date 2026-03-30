#!/bin/bash
# ============================================
# PHASE 10.5: HOME DIRECTORY ROOT FILES
# ============================================
log_section "Phase 10.5: Home Directory Root Files"

log_info "Scanning home directory for loose files..."

# Find files in home directory root (exclude hidden files and standard dirs)
HOME_FILES=$(find "$USER_HOME" -maxdepth 1 -type f ! -name ".*" 2>/dev/null || true)

if [[ -n "$HOME_FILES" ]]; then
    FILE_COUNT=$(echo "$HOME_FILES" | wc -l)
    log_info "Found $FILE_COUNT files in home directory root"
    
    # Show user what was found
    echo ""
    echo -e "${YELLOW}Files found:${NC}"
    echo "$HOME_FILES" | while read -r file; do
        BASENAME=$(basename "$file")
        SIZE=$(du -h "$file" | cut -f1)
        echo -e "  • ${CYAN}$BASENAME${NC} ($SIZE)"
    done
    echo ""
    
    read -p "Archive these files? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$ARCHIVE_DIR/home-root-files"
        
        # Categorize files as we copy them
        log_info "Archiving and categorizing files..."
        
        echo "$HOME_FILES" | while read -r file; do
            if [[ -f "$file" ]]; then
                BASENAME=$(basename "$file")
                EXTENSION="${BASENAME##*.}"
                
                # Categorize by type
                case "$EXTENSION" in
                    txt|log|md)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/text"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/text/"
                        ;;
                    sh|py|rb|pl|php|js)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/scripts"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/scripts/"
                        ;;
                    zip|tar|gz|bz2|7z|rar)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/archives"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/archives/"
                        ;;
                    pcap|pcapng|cap)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/captures"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/captures/"
                        ;;
                    xml|json|csv|xlsx|xls)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/data"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/data/"
                        ;;
                    exe|dll|bin|elf)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/binaries"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/binaries/"
                        ;;
                    pdf|doc|docx|odt)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/documents"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/documents/"
                        ;;
                    jpg|jpeg|png|gif|bmp|svg)
                        mkdir -p "$ARCHIVE_DIR/home-root-files/images"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/images/"
                        ;;
                    *)
                        # Unknown/other files
                        mkdir -p "$ARCHIVE_DIR/home-root-files/other"
                        cp "$file" "$ARCHIVE_DIR/home-root-files/other/"
                        ;;
                esac
            fi
        done
        
        log_info "✓ Files archived and categorized"
        
        # Create inventory file
        log_info "Creating file inventory..."
        cat > "$ARCHIVE_DIR/home-root-files/INVENTORY.txt" << EOFINV
# Home Directory Root Files Inventory
# Archived: $(date)

Total files archived: $FILE_COUNT

## Files by Category:

EOFINV
        
        # List files in each category
        for category in text scripts archives captures data binaries documents images other; do
            if [[ -d "$ARCHIVE_DIR/home-root-files/$category" ]]; then
                COUNT=$(ls -1 "$ARCHIVE_DIR/home-root-files/$category" 2>/dev/null | wc -l)
                if [[ $COUNT -gt 0 ]]; then
                    echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                    echo "### $category/ ($COUNT files):" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                    ls -lh "$ARCHIVE_DIR/home-root-files/$category" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}' >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                fi
            fi
        done
        
        # Check for interesting patterns in text files
        log_info "Analyzing text files for interesting content..."
        
        if [[ -d "$ARCHIVE_DIR/home-root-files/text" ]]; then
            # Search for common pentest artifacts
            echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            echo "## Content Analysis (Text Files):" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            
            # Look for potential credentials/hashes
            CRED_FILES=$(grep -l -i -E "(password|pwd|hash|ntlm|lm:|administrator)" "$ARCHIVE_DIR/home-root-files/text"/* 2>/dev/null || true)
            if [[ -n "$CRED_FILES" ]]; then
                echo "Files containing potential credentials:" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                echo "$CRED_FILES" | while read -r f; do
                    echo "  - $(basename $f)" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                done
                echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            fi
            
            # Look for IPs
            IP_FILES=$(grep -l -E "([0-9]{1,3}\.){3}[0-9]{1,3}" "$ARCHIVE_DIR/home-root-files/text"/* 2>/dev/null || true)
            if [[ -n "$IP_FILES" ]]; then
                echo "Files containing IP addresses:" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                echo "$IP_FILES" | while read -r f; do
                    echo "  - $(basename $f)" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                done
                echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            fi
            
            # Look for URLs
            URL_FILES=$(grep -l -E "https?://" "$ARCHIVE_DIR/home-root-files/text"/* 2>/dev/null || true)
            if [[ -n "$URL_FILES" ]]; then
                echo "Files containing URLs:" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                echo "$URL_FILES" | while read -r f; do
                    echo "  - $(basename $f)" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
                done
                echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            fi
        fi
        
        log_info "✓ Inventory created"
        
        # Option to delete files
        echo ""
        read -p "Delete archived files from home directory? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$HOME_FILES" | while read -r file; do
                rm -f "$file" 2>/dev/null || true
            done
            log_info "✓ Files deleted from home directory"
        fi
    else
        log_info "Skipping home directory files"
    fi
else
    log_info "No loose files found in home directory root"
fi

# Also check for hidden files that might be interesting
log_info "Checking for interesting hidden files..."

HIDDEN_FILES=$(find "$USER_HOME" -maxdepth 1 -type f -name ".*" ! -name ".bash*" ! -name ".zsh*" ! -name ".profile" ! -name ".bashrc" ! -name ".zshrc" 2>/dev/null || true)

if [[ -n "$HIDDEN_FILES" ]]; then
    HIDDEN_COUNT=$(echo "$HIDDEN_FILES" | wc -l)
    log_info "Found $HIDDEN_COUNT hidden files (excluding standard shell configs)"
    
    echo ""
    echo -e "${YELLOW}Hidden files found:${NC}"
    echo "$HIDDEN_FILES" | while read -r file; do
        BASENAME=$(basename "$file")
        SIZE=$(du -h "$file" | cut -f1)
        echo -e "  • ${CYAN}$BASENAME${NC} ($SIZE)"
    done
    echo ""
    
    read -p "Archive these hidden files? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$ARCHIVE_DIR/home-root-files/hidden"
        
        echo "$HIDDEN_FILES" | while read -r file; do
            if [[ -f "$file" ]]; then
                cp "$file" "$ARCHIVE_DIR/home-root-files/hidden/"
            fi
        done
        
        log_info "✓ Hidden files archived"
        
        # Add to inventory
        if [[ -f "$ARCHIVE_DIR/home-root-files/INVENTORY.txt" ]]; then
            echo "" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            echo "### hidden/ ($HIDDEN_COUNT files):" >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
            ls -lh "$ARCHIVE_DIR/home-root-files/hidden" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}' >> "$ARCHIVE_DIR/home-root-files/INVENTORY.txt"
        fi
    fi
fi
