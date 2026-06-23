import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── Google OAuth2 JWT for FCM HTTP v1 API ────────────────────────────────────

async function getFcmAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')!
  const privateKeyPem = Deno.env.get('FCM_PRIVATE_KEY')!.replace(/\\n/g, '\n')
  const now = Math.floor(Date.now() / 1000)

  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '')

  const signingInput = `${encode(header)}.${encode(payload)}`

  const keyData = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )

  const encodedSig = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')

  const jwt = `${signingInput}.${encodedSig}`

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const tokenData = await tokenRes.json()
  if (!tokenData.access_token) {
    throw new Error(`Token error: ${JSON.stringify(tokenData)}`)
  }
  return tokenData.access_token as string
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  try {
    const body = await req.json()
    const record = body.record as Record<string, string>

    const receiverId = record['receiver_id']
    const senderId = record['sender_id']
    const content = record['content'] ?? ''
    const type = record['type'] ?? 'text'

    if (!receiverId || !senderId) {
      return new Response('Missing IDs', { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Don't send push if the receiver has blocked the sender
    const [receiverRes, senderRes, blockRes] = await Promise.all([
      supabase.from('profiles').select('fcm_token').eq('id', receiverId).single(),
      supabase.from('profiles').select('name').eq('id', senderId).single(),
      supabase
        .from('blocked_users')
        .select('blocker_id', { count: 'exact', head: true })
        .eq('blocker_id', receiverId)
        .eq('blocked_id', senderId),
    ])

    if ((blockRes.count ?? 0) > 0) {
      return new Response('Sender is blocked', { status: 200 })
    }

    const fcmToken = receiverRes.data?.fcm_token as string | null
    if (!fcmToken) {
      return new Response('No FCM token', { status: 200 })
    }

    const senderName =
      ((senderRes.data?.name as string | null) ?? 'Alguém').split(' ')[0]

    const notifBody =
      type === 'poke'
        ? 'cutucou você 👋'
        : type === 'reaction'
        ? `reagiu: ${content}`
        : content

    const projectId = Deno.env.get('FCM_PROJECT_ID')!
    const accessToken = await getFcmAccessToken()

    const fcmPayload = {
      message: {
        token: fcmToken,
        notification: {
          title: senderName,
          body: notifBody,
        },
        data: {
          type: 'message',
          sender_id: senderId,
          sender_name: senderName,
          body: notifBody,
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: { sound: 'default', badge: 1, 'content-available': 1 },
          },
        },
        android: {
          notification: { sound: 'default' },
          priority: 'high',
        },
      },
    }

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(fcmPayload),
      },
    )

    const result = await fcmRes.json()
    return new Response(JSON.stringify(result), {
      status: fcmRes.ok ? 200 : 500,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
