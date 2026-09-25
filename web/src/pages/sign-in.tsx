import { zodResolver } from '@hookform/resolvers/zod'
import { getRouteApi, useRouter } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod'
import { ApiError } from '@/api/errors'
import { signIn } from '@/auth/auth'
import { useSession } from '@/auth/session'
import { FormField } from '@/components/form-field'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { FieldGroup } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Spinner } from '@/components/ui/spinner'
import { errorMessage } from '@/lib/errors'

const route = getRouteApi('/sign-in')

const schema = z.object({
  email: z.email('Enter your email address'),
  password: z.string().min(1, 'Enter your password'),
})

// Only a path on this origin. The browser reads //host as another host.
function safeRedirect(target: string | undefined): string {
  return target?.startsWith('/') && !target.startsWith('//') && !target.startsWith('/\\') ? target : '/analytics'
}

export function SignInPage() {
  const { redirect } = route.useSearch()
  const router = useRouter()
  const signedIn = useSession((session) => session.refreshToken !== null)
  const form = useForm({ resolver: zodResolver(schema), defaultValues: { email: '', password: '' } })
  const [alert, setAlert] = useState<string | null>(null)

  useEffect(() => {
    if (signedIn) void router.navigate({ href: safeRedirect(redirect), replace: true })
  }, [signedIn, redirect, router])

  if (signedIn) return null

  const onSubmit = form.handleSubmit(async ({ email, password }) => {
    setAlert(null)
    try {
      await signIn(email, password)
    } catch (error) {
      setAlert(error instanceof ApiError && error.status === 401 ? 'Email or password is incorrect.' : errorMessage(error))
    }
  })

  return (
    <main className="grid min-h-svh place-items-center bg-muted/40 p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle className="text-lg">Sign in</CardTitle>
          <CardDescription>Salaries, raises and pay history for ACME.</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} noValidate>
            <FieldGroup>
              {alert && (
                <Alert variant="destructive">
                  <AlertDescription>{alert}</AlertDescription>
                </Alert>
              )}
              <FormField control={form.control} name="email" label="Email">
                {(input) => <Input {...input} type="email" autoComplete="username" autoFocus />}
              </FormField>
              <FormField control={form.control} name="password" label="Password">
                {(input) => <Input {...input} type="password" autoComplete="current-password" />}
              </FormField>
              <Button type="submit" size="lg" disabled={form.formState.isSubmitting}>
                {form.formState.isSubmitting && <Spinner />}
                Sign in
              </Button>
            </FieldGroup>
          </form>
        </CardContent>
      </Card>
    </main>
  )
}
