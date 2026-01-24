import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai@0.21.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS Pre-flight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { url, is_executive } = await req.json()
    const apiKey = Deno.env.get('GEMINI_API_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!apiKey) throw new Error('GEMINI_API_KEY not found')
    if (!supabaseUrl || !supabaseServiceKey) throw new Error('Supabase Config Missing')
    if (!url) throw new Error('URL is required')

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    console.log(`Processing URL: ${url}. Executive: ${is_executive}`)

    // --- STEP 4: AI PROCESSING (Gemini) ---
    console.log("Generating recipe with Gemini...");
    
    // Executive Chefs get the cutting-edge 2.5 Flash
    // Others get the previous high-speed version (2.0 Flash)
    const modelVersion = is_executive ? 'gemini-2.5-flash' : 'gemini-2.0-flash-exp';
    console.log(`Using Model: ${modelVersion}`);

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: modelVersion });

    // --- PIPELINE VARIABLES ---
    let mediaBuffer: Uint8Array | null = null;
    let mimeType = "audio/mp3"; 
    let thumbnailVal: string | null = null;
    let videoTitle: string | null = null;
    let description: string | null = null;
    
    // Strategy Detection
    const isVideoSite = url.includes('instagram.com/reel') || 
                        url.includes('tiktok.com') || 
                        url.includes('youtube.com/shorts') || 
                        url.includes('youtube.com/watch');

    // --- STEP 0: METADATA SCRAPING ---
    console.log("Fetching page metadata...");
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);
        const siteRes = await fetch(url, { 
            headers: { 'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' },
            signal: controller.signal
        });
        clearTimeout(timeoutId);

        if (siteRes.ok) {
            const html = await siteRes.text();
            
            // Extract OG Tags
            const ogTitle = html.match(/<meta\s+property="og:title"\s+content="([^"]*)"/i)?.[1] || 
                            html.match(/<meta\s+name="title"\s+content="([^"]*)"/i)?.[1] ||
                            html.match(/<title>([^<]*)<\/title>/i)?.[1];
            
            const ogDesc = html.match(/<meta\s+property="og:description"\s+content="([^"]*)"/i)?.[1] ||
                           html.match(/<meta\s+name="description"\s+content="([^"]*)"/i)?.[1] ||
                           html.match(/<meta\s+name="twitter:description"\s+content="([^"]*)"/i)?.[1];

            const ogImage = html.match(/<meta\s+property="og:image"\s+content="([^"]*)"/i)?.[1] ||
                            html.match(/<meta\s+property="og:image:secure_url"\s+content="([^"]*)"/i)?.[1] ||
                            html.match(/<meta\s+name="twitter:image"\s+content="([^"]*)"/i)?.[1];

            if (ogTitle) videoTitle = ogTitle;
            if (ogDesc) description = ogDesc;
            if (ogImage) {
                // FIX: Decode HTML entities in URL (e.g. &amp; -> &) to prevent signature breakage
                thumbnailVal = ogImage.replace(/&amp;/g, '&');
            }
            
            console.log(`Metadata Found: Title="${videoTitle?.substring(0,20)}"`);
        }
    } catch (e) {
        console.warn("Metadata scrape failed:", e);
    }

    // --- STEP 1: MEDIA EXTRACTION ---
    if (isVideoSite) {
        console.log("Video site detected. Attempting extraction...");
        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 15000);

            const cobaltResponse = await fetch('https://api.cobalt.tools/api/json', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
                body: JSON.stringify({ 
                    url: url, 
                    isAudioOnly: true, 
                    aFormat: 'mp3',
                    filenamePattern: 'nerdy'
                }),
                signal: controller.signal
            });
            clearTimeout(timeoutId);

            if (cobaltResponse.ok) {
                const data = await cobaltResponse.json();
                if (data.picker) thumbnailVal = data.picker; 
                if (data.title && !videoTitle) videoTitle = data.title; 

                if (data.url) {
                    const mediaRes = await fetch(data.url);
                    if (mediaRes.ok) {
                        const blob = await mediaRes.blob();
                        const arrayBuffer = await blob.arrayBuffer();
                        if (arrayBuffer.byteLength < 20 * 1024 * 1024) { 
                             mediaBuffer = new Uint8Array(arrayBuffer);
                        }
                    }
                }
            }
        } catch (e) {
            console.error("Media extraction failed:", e);
        }
    }

    // --- STEP 2: PROMPT ---
    let promptParts = [];
    const systemPrompt = `
    You are a professional chef. Analyze content to extract a recipe.
    Source URL: ${url}
    ${videoTitle ? `Title: "${videoTitle}"` : ''}
    ${description ? `Caption: "${description}"` : ''}
    PRIORITY: Caption Text > Audio.
    Return JSON. If no recipe, return empty valid JSON.
    Structure:
    {
       "title": "String", "description": "String",
       "time": "String", "calories": "String", "macros": {"protein": "", "carbs": "", "fat": ""},
       "ingredients": [{"name": "", "amount": ""}],
       "instructions": ["Step 1"], "equipment": []
    }
    `;
    promptParts.push(systemPrompt);

    if (mediaBuffer) {
        promptParts.push({
            inlineData: {
                data: btoa(String.fromCharCode(...mediaBuffer)), // Audio is usually small enough
                mimeType: mimeType
            }
        });
    } else if (!description) {
         // Fallback scrape logic (elided for brevity but kept same principle)
         // ...
    }

    // --- STEP 3: GENERATE ---
    console.log("Sending to Gemini...");
    const result = await model.generateContent(promptParts);
    const textResponse = result.response.text();

    // --- STEP 4: PARSE ---
    const cleanedText = textResponse.replace(/```json/g, '').replace(/```/g, '').trim();
    let recipeData: any = {};
    try { recipeData = JSON.parse(cleanedText); } catch(e) {}

    let status = 'empty';
    if (recipeData.ingredients?.length > 1 && recipeData.instructions?.length > 0) {
        status = 'found';
        if (!recipeData.thumbnail && thumbnailVal) recipeData.thumbnail = thumbnailVal;
        if (!recipeData.title && videoTitle) recipeData.title = videoTitle;
    }

    // --- STEP 5: ROBUST IMAGE HANDLING (Storage -> Base64 -> Weserv Proxy) ---
    let debugLog: string[] = [];
    
    if (thumbnailVal && thumbnailVal.startsWith('http')) {
        debugLog.push("Processing thumbnail: " + thumbnailVal.substring(0, 30));
        let processedImage: string | null = null;
        let imageBuffer: ArrayBuffer | null = null;
        let contentType = 'image/jpeg';

        try {
             // 1. Fetch Image (Simulate Googlebot to bypass 403s)
            const thumbRes = await fetch(thumbnailVal, { 
                headers: { 'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' }
            });
            
            if (thumbRes.ok) {
                imageBuffer = await thumbRes.arrayBuffer();
                contentType = thumbRes.headers.get('content-type') || contentType;
                debugLog.push("Image fetched. Size: " + imageBuffer.byteLength);

                // STRATEGY 1: Base64 (Chunked) - User Preferred
                // We try to embed the image directly first.
                debugLog.push("Attempting Base64 Encoding...");
                try {
                    let binary = '';
                    const bytes = new Uint8Array(imageBuffer);
                    const len = bytes.byteLength;
                    const chunkSize = 1024;
                    for (let i = 0; i < len; i += chunkSize) {
                        const chunk = bytes.subarray(i, Math.min(i + chunkSize, len));
                        binary += String.fromCharCode.apply(null, Array.from(chunk));
                    }
                    processedImage = `data:${contentType};base64,${btoa(binary)}`;
                    debugLog.push("Base64 Success. Len: " + processedImage.length);
                } catch (b64Err) {
                    debugLog.push("Base64 Failed: " + b64Err);
                    // processedImage is still null, proceeds to Strategy 2
                }

                // STRATEGY 2: Supabase Storage (Fallback if Base64 failed)
                if (!processedImage) {
                    debugLog.push(`Keys: URL=${!!supabaseUrl}, Key=${!!supabaseServiceKey}`);
                    
                    if (supabaseUrl && supabaseServiceKey) {
                        debugLog.push("Attempting Storage Upload...");
                        const ext = contentType.split('/')[1] || 'jpg';
                        const filename = `recipes/import_${crypto.randomUUID()}.${ext}`;

                        const { error: uploadError } = await supabase
                            .storage
                            .from('images')
                            .upload(filename, imageBuffer, { contentType, upsert: true });

                        if (!uploadError) {
                            const { data: { publicUrl } } = supabase
                                .storage
                                .from('images')
                                .getPublicUrl(filename);
                            processedImage = publicUrl;
                            debugLog.push("Storage Upload Success: " + processedImage);
                        } else {
                            debugLog.push("Storage Upload Failed: " + uploadError.message);
                            // processedImage still null, proceeds to Weserv
                        }
                    } else {
                        debugLog.push("No Supabase Keys for Storage");
                    }
                }
            } else {
                debugLog.push("Fetch failed: " + thumbRes.status);
            }
        } catch (e) {
            debugLog.push("Processing Error: " + e.message);
            // No need to try Base64 here because we likely failed to fetch the buffer in the first place.
        }

        // 4. Final Fallback: Weserv Proxy
        // If we still don't have a processed image (fetch failed or processing failed),
        // we use a public proxy that often bypasses restrictions.
        if (processedImage) {
            thumbnailVal = processedImage;
            // Update the recipe object too so it persists
            if (status === 'found') recipeData.thumbnail = thumbnailVal;
        } else {
            debugLog.push("Using Weserv Fallback");
            // Use Weserv.nl as a caching proxy
            thumbnailVal = `https://wsrv.nl/?url=${encodeURIComponent(thumbnailVal)}&output=jpg&w=800&q=80`;
            if (status === 'found') recipeData.thumbnail = thumbnailVal;
        }
    }

    console.log("Debug Log:", JSON.stringify(debugLog));

    // Response Object
    return new Response(JSON.stringify({
        status: status,
        recipe: status === 'found' ? recipeData : null,
        metadata: {
            title: videoTitle || recipeData.title || "Shared Link",
            thumbnail: thumbnailVal
        },
        debug: debugLog
    }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ status: 'error', error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
